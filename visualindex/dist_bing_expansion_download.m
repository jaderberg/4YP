% Max Jaderberg 4/3/12

% UPDATE: 12/10/12 Pre download images. For history I'm keeping the bing
% names

function dist_bing_expansion_download( n_split, N_split, first_host, this_host )

[root_dir image_dir num_words] = dist_setup(n_split, N_split);

import com.mongodb.BasicDBObject;

%     load config file
try
    conf = load(fullfile(root_dir, 'conf.mat'));
    try
        conf = conf.conf;
    catch
        conf = conf;
    end
catch err
    fprintf('ERROR: could not find conf.mat. Make sure preprocess_solution.m has been run.\n');
    result = 0;
    return
end

%     get mongodb collection
[m db coll] = mongo_get_collection('server',first_host);

% get vocab
vocab_file = fullfile(conf.modelDataDir, 'vocab.mat');
vocab = load(vocab_file);

% get class names
m = load(fullfile(conf.modelDataDir, 'class_names.mat'));
class_names = m.class_names;

opts.maxResolution = 1000;
opts.nPhotos = 25;
opts.matchThresh = 9;
opts.force = 1;


conf.bingDir = '~/4YP/data/ukno1albums_google';

% Create a report on expansion
conf.expansionResultsDir = fullfile(conf.rootDir, 'bing_expansion_results');
vl_xmkdir(conf.expansionResultsDir);
total_expanded = 0;
class_total_expanded = 0;

% split classes up
split = floor(length(class_names)/N_split);
start_class = (n_split-1)*split + 1;
end_class = start_class + split - 1;
fprintf('Split %d of %d\n', n_split, N_split);
if n_split == N_split
    class_names = class_names(start_class:end);
else
    class_names = class_names(start_class:end_class);
end

ids = {};
histograms = {};

n_image = 1;
for n=1:length(class_names)
    class_name = class_names{n};
    
    % Check if already done this class fully
    class_ims = coll.find(BasicDBObject('class', class_name));
    n_class_ims = class_ims.count();
    already_done = 0;
    if ~opts.force          
        for i=1:n_class_ims
            class_im = class_ims.next();
            c_id = class_im.get('_id').toString.toCharArray';
            if exist(fullfile(conf.wordsDataDir, [c_id '-bingaugmentedwords.mat']))
                already_done = already_done + 1;
            end
        end
    end
    
    if already_done == n_class_ims
        % already done the bing expansion for this class so just load
        % the histograms
        fprintf('Class %s already expanded - loading data...\n', class_name);
        class_ims = coll.find(BasicDBObject('class', class_name));
        for i=1:class_ims.count()
            class_im = class_ims.next();
            c_id = class_im.get('_id').toString.toCharArray';
            m = load(fullfile(conf.wordsDataDir, [c_id '-bingaugmentedwords.mat']));
            c_words = m.c_words;
            clear m;
            % create the new histogram
            im_histogram = sparse(double(c_words),1,...
                         ones(length(c_words),1), ...
                         vocab.size,1) ;
            histograms{n_image} = im_histogram;
            ids{n_image} = c_id;

            n_image = n_image + 1;
        end
        % now on to next class
        continue
    end
    
    %-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-         
    %         Download images first...
    %-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=
        
    class_dir = fullfile(conf.bingDir, class_name);
    fprintf('Expanding images for class %s...\n', class_name);
    
    % See how many photos in the directory
    files = dir(fullfile(class_dir, '*.jpg')) ;
    files = [files; dir(fullfile(class_dir, '*.jpeg'))];
    files = {files(~[files.isdir]).name} ; 
    
    n_files = length(files);
    if opts.nPhotos > n_files
        warning('There are not enough pre-downloaded files to expand the full amount');
    end
    n_photos = n_files;

    f_filenames = {};
    f_words = {};
    f_frames = {};
    for i=1:n_photos
        filename = files{i};
        try
            fprintf('Reading %s...', filename);
            im = imread(fullfile(class_dir, filename));
            fprintf('loaded!\n');
        catch exc
            % this seems to be due to unknown image format or something?!
            fprintf('ERROR - skipping\n');
            continue
        end
        % resize if huge
        [maxRes maxDim] = max(size(im));
        if maxRes > 1000
            scale_factor = 1000/maxRes;
            im = imresize(im, scale_factor);
            imwrite(im, fullfile(class_dir, filename));
        end
        
%             get features + words
        try
            [frames, descrs] = visualindex_get_features(im);
            words = visualindex_get_words(vocab, descrs);
        catch
            fprintf('Error getting features - skipping\n');
            continue
        end
        f_filenames{i} = filename;
        f_words{i} = words;
        f_frames{i} = frames;
        clear im words frames descrs;
    end
    
    
    %-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=         
    %         Now do the combining with the existing images
    %-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    fprintf('Augmenting bing image words for %s...\n', class_name);
    % Create report folder
    class_report_dir = fullfile(conf.expansionResultsDir, class_name);
    vl_xmkdir(class_report_dir);
    class_total_expanded = 0;
%         get images of this class
    class_ims = coll.find(BasicDBObject('class', class_name));
    for i=1:class_ims.count()
        class_im = class_ims.next();
        fprintf('-> %s (%d of %d)\n', class_im.get('name'), i, class_ims.count());
        c_id = class_im.get('_id').toString.toCharArray';
        c_frames = load_frames(c_id, conf);
        c_words = load_words(c_id, conf);
        c_im = imread(class_im.get('path'));

        extra_words = [];
%             for each bing image for this class try and pull in some
%             words if it is spatially verified
        for j=1:length(f_filenames) 
            if isempty(f_filenames{j})
                continue
            end
            fprintf('Trying to match %s...\n', f_filenames{j});
            [score matches] = spatially_verify(c_frames,c_words,f_frames{j},f_words{j},size(c_im), 'includeRepeated', 0, 'repeatedScore', 0);
            if score > opts.matchThresh
                fprintf('### %s from bing is similar (score: %d) - adding words\n', f_filenames{j}, score);
                f_im = imread(fullfile(class_dir, f_filenames{j}));
                figure(1); clf;
                set(1, 'units','normalized','outerposition',[0 0 1 1])
                subplot_tight(2,2,1,[0.02 0.01]);
                imagesc(c_im) ; title('Class image') ;
                axis image off ; drawnow ;
                subplot_tight(2,2,2,[0.02 0.01]);
                imagesc(f_im) ; title('Expanded image') ;
                axis image off ; drawnow ;
                subplot_tight(2,2,3,[0.02 0.01]);
                visualindex_plot_matches(matches, c_im, f_im) ;
%                 save_figure(1, fullfile(class_report_dir, [c_id '|' f_filenames{j}]));
                total_expanded = total_expanded + 1;
                class_total_expanded = class_total_expanded + 1;
%                     rectangle of matched words on bing image
                f_xmin = min(matches.f2(1,:)); f_ymin = min(matches.f2(2,:));
                f_xmax = max(matches.f2(1,:)); f_ymax = max(matches.f2(2,:));
                transformation = inv([matches.A matches.T; 0 0 1]);
                % bring in all words in bing image within the
                % rectangle
                all_f_frames = f_frames{j};
                l = find(f_xmin<=all_f_frames(1,:)); r = find(all_f_frames(1,:)<=f_xmax);
                b = find(f_ymin<=all_f_frames(2,:)); t = find(all_f_frames(2,:)<=f_ymax);
                extra_i = intersect(t,intersect(b,intersect(r,l)));
                extra_frames_f = all_f_frames(:,extra_i);
                extra_words = f_words{j}(extra_i);
                % transform frames to wiki image coords
                Xc = transformation*[extra_frames_f(1:2,:); ones(1,length(extra_words))];
                extra_frames_c = [Xc(1:2,:); extra_frames_f(3:end,:)];
                c_frames = [c_frames extra_frames_c];
                c_words = [c_words extra_words];
            else
                fprintf('--- %s from bing is not similar (score: %d) - ignoring\n', f_filenames{j}, score);
            end
        end

        fprintf('--- Saving augmented frames and words for image %d\n', n_image);

        % save the augmented frames and words
        save(fullfile(conf.framesDataDir, [c_id '-bingaugmentedframes.mat']), 'c_frames');
        save(fullfile(conf.wordsDataDir, [c_id '-bingaugmentedwords.mat']), 'c_words');

        % create the new histogram
        im_histogram = sparse(double(c_words),1,...
                     ones(length(c_words),1), ...
                     vocab.size,1) ;
        save(fullfile(conf.histogramsDataDir, [c_id '-bingaugmentedrawhistogram.mat']), 'im_histogram');
        histograms{n_image} = im_histogram;
        ids{n_image} = c_id;

        n_image = n_image + 1;
    end

    class_report_txt = fopen(fullfile(class_report_dir, 'report.txt'), 'w');
    fprintf(class_report_txt, 'Expanded %d of %d (%f percent)\n', class_total_expanded, class_ims.count(), class_total_expanded*100/class_ims.count());
    fclose(class_report_txt);
end

fprintf('Saving raw histograms and ids...\n');
save(fullfile(conf.modelDataDir, [int2str(n_split) 'histograms-raw-bing.mat']), 'histograms');
save(fullfile(conf.modelDataDir, [int2str(n_split) 'ids-bing.mat']), 'ids');
fprintf('All done!\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');
