% Max Jaderberg 24/10/12

% Works out the object location ellipse from word votes. If no word votes
% then just by feature locations.

function local_object_location_estimation_mser( n_split, N_split, first_host, this_host)
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
        else
            % there was no turbo boosting so just estimate from all
            % features
            word_votes = ones(size(word_votes));
        end
        
        % work out weighted mean and cov
        X = frames(1:2,:);
        word_votes = word_votes./sum(word_votes);
        w = [word_votes; word_votes];
        xmean = sum(w.*X, 2);
        C = weightedcov(X', word_votes);
        region = [xmean; C(1,1); C(1,2); C(2,2)];
        save(fullfile(object_region_dir, [image_id '-region.mat']), 'region');
        
        try
            im = imread(strrep(image.get('path'), '~/4YP/data/d_wordvotes/', '/Volumes/4YP/d_rootaffine_turbo+/'));
        catch err
            fprintf('Error loading image\n');
            continue
        end
        figure(1); clf;
        imagesc(im) ; title(['Word votes ' image_id ]) ;
        axis image off ; drawnow ;
        vl_plotframe(region, 'Color', 'magenta');
        if voting
            save_figure(1, fullfile(object_voted_results_dir, [image_id '-cov']));
        else
            save_figure(1, fullfile(object_normal_results_dir, [image_id '-cov']));
        end

        %% now try and use that mean and covariance someway... 
        
        % get the mser regions
        try
            I = uint8(rgb2gray(im)) ;
        catch err
            fprintf('ERROR: %s', err.message);
        end
        im_area = size(im,1)*size(im,2);
        C_area = prod(sqrt(eig(C)))*pi ; % see comments of http://www.mathworks.com/matlabcentral/fileexchange/4705
        area_ratio = C_area/im_area;
        [r,f] = vl_mser(I,...
                        'MinArea',area_ratio,...
                        'MaxArea',0.9,...
                        'MinDiversity',0.2,...
                        'MaxVariation',0.25,...
                        'Delta',5) ;
        f = vl_ertr(f) ;
        vl_plotframe(f) ;
        vl_plotframe(region, 'Color', 'magenta');
        
        
        % choose mser ellipse which is most similar to cov ellipse (?!)
        err_best = inf;
        for i=1:size(f, 2)
            fi = f(:,i);
            err = norm([1000; 1000; 1; 1; 1].*(region - fi));
            if err < err_best
                f_best = fi;
                r_best = r(i);
                err_best = err;
            end
        end
        vl_plotframe(f_best, 'Color', 'red');
        if voting
            save_figure(1, fullfile(object_voted_results_dir, [image_id '-mserf']));
        else
            save_figure(1, fullfile(object_normal_results_dir, [image_id '-mserf']));
        end
        
        % plot mser region
        M = zeros(size(I)) ;
        s = vl_erfill(I,r_best) ;
        M(s) = M(s) + 1;
        clf ; imagesc(I) ; hold on ; axis equal off; colormap gray ;
        [c,h]=contour(M,(0:max(M(:)))+.5) ;
        set(h,'color','y','linewidth',3) ;
        if voting
            save_figure(1, fullfile(object_voted_results_dir, [image_id '-mserr']));
        else
            save_figure(1, fullfile(object_normal_results_dir, [image_id '-mserr']));
        end
        
        fprintf('All done!\n');
    end

    