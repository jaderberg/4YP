% Max Jaderberg 24/10/12

% Works out the object location ellipse from word votes. If no word votes
% then just by feature locations.

function local_object_location_estimation_convhullkmeansnoweight( n_split, N_split, first_host, this_host)
    [root_dir image_dir num_words] = local_setup(n_split, N_split);

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

    import com.mongodb.BasicDBObject;

    % split images into N parts
    total_ims = coll.find().count();
    split = floor(total_ims/N_split);
    start_image = (n_split-1)*split;
    fprintf('Split %d of %d\n', n_split, N_split);
    if n_split == N_split
        coll_ims = coll.find().sort(BasicDBObject('name',1)).skip(start_image);
    else
        coll_ims = coll.find().sort(BasicDBObject('name',1)).skip(start_image).limit(split);
    end
    
    object_region_dir = fullfile(conf.dataDir, 'object_regions');
    vl_xmkdir(object_region_dir);
    object_voted_results_dir = fullfile(conf.rootDir, 'voted_regions');
    vl_xmkdir(object_voted_results_dir);
    object_normal_results_dir = fullfile(conf.rootDir, 'normal_regions');
    vl_xmkdir(object_normal_results_dir);
    

    while coll_ims.hasNext()
        image = coll_ims.next();
        image_id = image.get('_id').toString.toCharArray';
        image_name = image.get('name');
        
%         if exist(fullfile(object_region_dir, [image_id '-convhullkmeans.mat']), 'file')
%             fprintf('Skipping\n');
%             continue
%         end

        fprintf('Estimating object location for %s\n', image_name);
        
        frames = load_frames(image_id, conf, 'prefix', 'bingaugmented');
        word_votes_file = fullfile(conf.wordsDataDir, [image_id '-wordvotes.mat']);
        t = load(word_votes_file);
        fields = fieldnames(t);
        if isempty(fields);
            word_votes = [];
        else
            word_votes = t.(fields{1});
        end
        
        % Are we using the voted features?
        voting = 0;
        if sum(word_votes)
            % there are some high voted words, so just use word votes
            voting = 1;
            word_votes = ones(size(word_votes));
        else
            % there was no turbo boosting so just estimate from all
            % features
            word_votes = ones(size(word_votes));
        end
        
        % do weighted kmeans
        
        % work out convex hull of features
        good_frames = frames(:, word_votes > 0);
        try
            try
                kmeansopts.weight = word_votes';
                [IDX, C, D] = fkmeans(good_frames(1:2,:)', 10, kmeansopts);
            catch
                [IDX, C] = kmeans(good_frames(1:2,:)', 10);
            end
            x = C(:,1); y = C(:,2);
        catch
            x = good_frames(1,:)'; y = good_frames(2,:)';
        end
        k = convhull(x,y);
%         save(fullfile(object_region_dir, [image_id '-convhullkmeans.mat']), 'k');
        
        try
            im = imread(strrep(image.get('path'), '~/4YP/data/d_wordvotes/', '/Volumes/4YP/d_rootaffine_turbo+/'));
        catch err
            fprintf('Error loading image\n');
            continue
        end
        figure(1); clf;
        imagesc(im) ; title(['Word votes ' image_id ]) ;
        axis image off ; drawnow ;
        hold on;
        plot(x(k),y(k),'r-', 'LineWidth', 2);
%         plot(x,y,'g.', 'LineWidth', 1);
        hold off;
        if voting
            save_figure(1, fullfile(object_voted_results_dir, [image_id '-hullanoweightkmeans']));
        else
            save_figure(1, fullfile(object_normal_results_dir, [image_id '-hullanoweightkmeans']));
        end

        
        fprintf('All done!\n');
    end

    