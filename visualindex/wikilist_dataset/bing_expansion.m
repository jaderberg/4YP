% Max Jaderberg 16/1/12

function [conf, vocab, histograms, ids] = bing_expansion(classes, conf, coll, vocab, varargin)
%     Expands on the images from Wikipedia using publicly available Bing
    import com.mongodb.BasicDBObject;
    
    opts.maxResolution = 1000;
    opts.nPhotos = '25';
    opts.matchThresh = 9;
    opts.force = 0;
    opts = vl_argparse(opts, varargin);

    app_id = '243C9AAF515AE3EE49D775D19F5F8F3F0F0A3D84';
    
    conf.bingDir = fullfile(conf.rootDir, 'bing_images');
    vl_xmkdir(conf.bingDir);
    
    ids = {};
    histograms = {};
    
    n_image = 1;
    for n=1:length(classes)
        class_name = classes{n};
        
        % Check if already done this class fully
        class_ims = coll.find(BasicDBObject('class', class_name));
        n_class_ims = class_ims.count();
        already_done = 0;
        if ~opts.force          
            for i=1:n_class_ims
                class_im = class_ims.next();
                c_id = class_im.get('_id').toString.toCharArray';
                if exist(fullfile(conf.wordsDataDir, [c_id '-augmentedwords.mat']))
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
                m = load(fullfile(conf.wordsDataDir, [c_id '-augmentedwords.mat']));
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
        vl_xmkdir(class_dir);
        fprintf('Expanding images for class %s...\n', class_name);
        search_term = class_name;
        search_term = strrep(search_term, ' ', '%20');
        search_term = strrep(search_term, '_', '%20');

        request_url = ['http://api.bing.net/json.aspx?' ...
                       'AppId=' app_id ...
                       '&Query=' search_term ...
                       '&Sources=Image' ...
                       '&Version=2.0' ...
                       '&Adult=Strict' ...
                       '&Image.Count=' opts.nPhotos ...
                       '&Image.Filters=Style:Photo+Size:Large' ...
                       '&JsonType=raw' ...
                      ];
        fprintf('Searching bing for %s...\n', search_term);
        try
            response = urlread(request_url);
        catch
            try
                response = urlread(request_url);
            catch
                response = [];
            end
        end
        resp_struct = parse_json(response);

        try
            photos = resp_struct{1}.SearchResponse.Image.Results;
        catch 
            photos = [];
        end
        n_photos = length(photos);

        fprintf('Downloading %d photos to %s...\n', n_photos, conf.imageDir);
        
        f_filenames = {};
        f_words = {};
        f_frames = {};
        for i=1:n_photos
            try
                photo_struct = photos{i};
            catch
                continue
            end
            fprintf('-> %s (%d of %d)\n', photo_struct.Title, i, n_photos);
            filename = [class_name '|' strrep(strrep(photo_struct.Title, '.', ''), '/', '') int2str(i) '.jpg'];
%             check if photo exists
            if exist(fullfile(class_dir, filename), 'file')
                fprintf('   ...file already exists!\n');
                im = imread(fullfile(class_dir, filename));
            else          
    %             grab it from bing
                photo_url = photo_struct.MediaUrl;
                fprintf('   ...downloading %s\n', photo_url);
                try
                    im = imreadurl(photo_url,30000);
                catch err
                    try
                        im = imread(photo_url,60000);
                    catch err
                        fprintf('   ...ERROR: TIMEOUT\n');
                        continue
                    end
                end
    %             resize if too big
                if opts.maxResolution
                    [maxRes maxDim] = max(size(im));
                    if maxRes > opts.maxResolution
                        scale_factor = opts.maxResolution/maxRes;
                        im = imresize(im, scale_factor);
                    end
                end
    %             save to bingDir
                fprintf('   ...saved as %s!\n', filename);
                try
                    imwrite(im, fullfile(class_dir, filename));
                catch
                    try
                        imwrite(im, fullfile(class_dir, filename));
                    catch
                        fprintf('   ...ERROR: FAILED imwrite\n');
                        continue
                    end
                end
            end
%             get features + words
            [frames, descrs] = visualindex_get_features(im);
            words = visualindex_get_words(vocab, descrs);
            f_filenames{i} = filename;
            f_words{i} = words;
            f_frames{i} = frames;
            clear im words frames descrs;
        end
        
%-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=         
%         Now do the combining with the existing images
%-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        fprintf('Augmenting bing image words for %s...\n', class_name);
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
                [score matches] = spatially_verify(c_frames,c_words,f_frames{j},f_words{j},size(c_im), 'includeRepeated', 0, 'repeatedScore', 0);
                if score > opts.matchThresh
                    fprintf('### %s from bing is similar (score: %d) - adding words\n', f_filenames{j}, score);
                    f_im = imread(fullfile(class_dir, f_filenames{j}));
                    figure(1)
                    visualindex_plot_matches(matches, c_im, f_im) ;
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
                end
            end
            
            fprintf('--- Saving augmented frames and words for image %d\n', n_image);
            
            % save the augmented frames and words
            save(fullfile(conf.framesDataDir, [c_id '-augmentedframes.mat']), 'c_frames');
            save(fullfile(conf.wordsDataDir, [c_id '-augmentedwords.mat']), 'c_words');
            
            % create the new histogram
            im_histogram = sparse(double(c_words),1,...
                         ones(length(c_words),1), ...
                         vocab.size,1) ;
            histograms{n_image} = im_histogram;
            ids{n_image} = c_id;
            
            n_image = n_image + 1;
        end
    end
    
fprintf('Creating tf-idf weighted histograms with bing augmentented words...\n');
    
% compute IDF weights
histograms = cat(2, histograms{:});
vocab.weights = log((size(histograms,2)+1)./(max(sum(histograms > 0,2),eps))) ;
save(fullfile(conf.modelDataDir, 'vocab_augmented.mat'), '-STRUCT', 'vocab');

% weight and normalize histograms
for t = 1:length(ids)
    image_id = ids{t};
    
    fprintf('Creating augmented histogram for %s\n', image_id)
%         apply weightingz
    h = histograms(:,t) .*  vocab.weights ;
    im_histogram = h / max(sum(histograms(:,t)), eps) ;
    clear h;
    save(fullfile(conf.histogramsDataDir, [image_id '-augmentedhistogram.mat']), 'im_histogram');
    
    histograms(:,t) = im_histogram;
end

save(fullfile(conf.modelDataDir, 'ids_augmented.mat'), 'ids');
save(fullfile(conf.modelDataDir, 'histograms_augmented.mat'), 'histograms');