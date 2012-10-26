% Max Jaderberg 24/10/12

% Works out the object location ellipse from word votes. If no word votes
% then just by feature locations.

function local_object_location_estimation_convhullkmeans( n_split, N_split, first_host, this_host)
    [root_dir image_dir num_words] = dist_setup(n_split, N_split);

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
    object_results_dir = fullfile(conf.rootDir, 'object_region_results');
    vl_xmkdir(object_results_dir);

    

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
            word_votes = ones(size(word_votes)) + 100.*word_votes;
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
        % add 20% to the hull (move away from centroid)
        hull = [x(k) y(k)];
        hull_centre = mean(hull);
        hull = hull + 0.2*(hull - [hull_centre(1)*ones(size(hull,1),1) hull_centre(2)*ones(size(hull,1),1)]);
        
        try
            im = imread(image.get('path'));
        catch err
            fprintf('Error loading image\n');
            continue
        end
        
        % hull max is edge of image
        h = size(im,1); w = size(im,2);
        hull(hull(:,1) > w,1) = w;
        hull(hull(:,1) < 0,1) = 0;
        hull(hull(:,2) > h,2) = h;
        hull(hull(:,2) < 0,2) = 0;
        save(fullfile(object_region_dir, [image_id '-convhullkmeans.mat']), 'k');
        
        figure(1); clf;
        imagesc(im) ; title(['Word votes ' image_id ]) ;
        axis image off ; drawnow ;
        hold on;
        plot(hull(:,1),hull(:,2),'r-', 'LineWidth', 2);
%         plot(x,y,'g.', 'LineWidth', 1);
        hold off;
        save_figure(1, fullfile(object_results_dir, [image_id '-hullkmeans']));

        
    end
    
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
    if ~isfield(conf, 'object_region_dir')
        conf.object_region_dir = object_region_dir;
        % save conf
        save(fullfile(conf.rootDir, 'conf.mat'), '-STRUCT', 'conf');
    end
    fprintf('All done!\n');
    % save file to signal good ending
    a = 1;
    save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');

    