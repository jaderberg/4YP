% Max Jaderberg 5/3/12

function result = dist_get_objects(args, conf, coll)

% Returns the matched object and region of matchings. Must run
% preprocess_solution.m once before this works. Also the mongodb java
% library must be imported by running javaaddpath('mongo-2.7.2.jar')

%--------------------------------------------------------------------------
% SET THIS TO THE ROOT_DIR USED IN preprocess_solution.m
    ROOT_DIR = '~/4YP/data/d_colourmodel_ra';
%=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

%--------------------------------------------------------------------------
% IF TURBO MODE THEN SET TO 'bingaugmented', else ''
    global file_prefix;
    file_prefix = 'bingaugmented';
%=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

%--------------------------------------------------------------------------
% OJBECT REGION METHOD TO USE, only one should be 1
    rect_method = true;
    ellipse_method = false;
    hull_method = false;
%=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    import com.mongodb.BasicDBObject;
    import org.bson.types.ObjectId;
    
%     parse input arguments
    imagePath = args.image_path;
    display = 0;
    if isfield(args, 'display')
        display = args.display;
    end
    
%     setup log file
    if ~isfield(args, 'log_file')
        args.log_file = 'log.txt';
    end
    log_file = fopen(args.log_file, 'w');
    
    
%     define global variables to avoid reloading from disk
    global histograms
    global ids
    global vocab
    global class_names
    global class_hists
    global classes_useful_hists
    
    if isempty(histograms) || isempty(ids) || isempty(vocab)
        fprintf('Loading histograms from %s\n', conf.modelDataDir);
        fprintf(log_file, 'Loading histograms from %s\n', conf.modelDataDir);
        m = load(fullfile(conf.modelDataDir, 'histograms-bing-all.mat'));
        histograms = m.histograms;
        fprintf('Loading ids from %s\n', conf.modelDataDir);
        fprintf(log_file, 'Loading ids from %s\n', conf.modelDataDir);
        m = load(fullfile(conf.modelDataDir, 'ids-bing-all.mat'));
        ids = m.ids;
        fprintf('Loading vocab from %s\n', conf.modelDataDir);
        fprintf(log_file, 'Loading vocab from %s\n', conf.modelDataDir);
        vocab = load(fullfile(conf.modelDataDir, 'vocab-bing.mat'));
        fprintf('Loading super histograms...\n');
        m = load(fullfile(conf.modelDataDir, 'class_names.mat'));
        class_names = m.class_names;
%         m = load(fullfile(conf.modelDataDir, 'class_histograms.mat'));
%         class_hists = m.super_class_histograms;
%         m = load(fullfile(conf.modelDataDir, 'classes_useful_hists.mat'));
%         classes_useful_hists = m.classes_useful_hists;
        clear m;
    end

    %     Read Image and resize if too large
    fprintf('Querying image %s\n', imagePath) ;
    fprintf(log_file, 'Querying image %s\n', imagePath) ;
    im = imread(imagePath) ;
    [maxRes maxDim] = max(size(im));
    maxAllowedRes = 1000;
    if maxRes > maxAllowedRes
        scale_factor = maxAllowedRes/maxRes;
        im = imresize(im, scale_factor);
    end
    sz = [size(im,2); size(im,1)] ;

    if display
    %     Plot image
        figure(1) ; clf ;
        set(1, 'units','normalized','outerposition',[0 0 1 1])
        subplot_tight(2,2,1,[0.02 0.01]);
        imagesc(im) ; title(sprintf('Query: %s', imagePath)) ;
        axis image off ; drawnow ;
    end
    
    %     Now do multiple object matching!
    max_objects = 1;
    max_tries_per_object = 2;
    
    result.query_image.path = imagePath;
    result.query_image.sz = sz;
    result.matches = {};
    result.classes = {};
    
    exclusion_matrix = [];
    pass_number = 1;
    current_tries = 0;
    
    frames = []; descrs = [];
    
    fprintf('Starting match process...\n');
    fprintf(log_file, 'Starting match process...\n');
    
    while pass_number < max_objects*max_tries_per_object
        
        try
            [best_match frames descrs] = image_query(im, histograms, ids, vocab, conf, coll, 'excludeClasses', result.classes,'exclude', exclusion_matrix,'frames', frames, 'descrs', descrs);
        catch exc
            fprintf('Image query error: %s\n', exc.message);
            break
        end
            
            
        fprintf('Match has a score of %d. ', best_match.score);
        fprintf(log_file, 'Match has a score of %d. ', best_match.score);
        if best_match.score < 5 || isnan(best_match.score)
            fprintf('Score not large enough to be certain - no match\n');
            fprintf(log_file, 'Score not large enough to be certain - no match\n');
            break
        end
        
        db_im = coll.findOne(BasicDBObject('_id', ObjectId(best_match.id)));
        match_image.class = db_im.get('class');
        
        if isempty(match_image.class)
            fprintf('Matched image has no class - no match\n');
            fprintf(log_file, 'Matched image has no class - no match\n');
            break
        end
        
        if find(ismember(result.classes, match_image.class)==1)
%             This object has already been found in the image
            fprintf('The recognised object (%s) has already been found\n', match_image.class);
            fprintf(log_file, 'The recognised object (%s) has already been found\n', match_image.class);
            current_tries = current_tries + 1;
            if current_tries >= max_tries_per_object
                fprintf('Search stopped as no new object found\n');
                fprintf(log_file, 'Search stopped as no new object found\n');
                break
            else
                continue
            end
        else
            fprintf('Found new object, %s\n', match_image.class);
            fprintf(log_file, 'Found new object, %s\n', match_image.class);
            result.classes{end+1} = match_image.class;
        end
        
        db_size = db_im.get('size');
        match_image.sz = [db_size.get('width') db_size.get('height')];
        if ~all(match_image.sz)
            fprintf('No size data - disregarding match\n');
            result.classes(end) = [];
            break;
        end
        match_image.path = db_im.get('path');
        match_image.image = imread(match_image.path);
        match_image.matches = best_match.match;
        
        if display
    %             Plot matched image
            figure(1);
            subplot_tight(2,2,3,[0.02 0.01]);
            imagesc(match_image.image) ; title(sprintf('Best match: %s', match_image.path)) ;
            axis image off ; drawnow ; hold on;
        end

        if rect_method
        %         Plot matches on query image and bounding rectangle
            match_coords_x = match_image.matches.f2(1,:);
            match_coords_y = match_image.matches.f2(2,:);
            xmin = min(match_coords_x); ymin = min(match_coords_y); xmax = max(match_coords_x); ymax = max(match_coords_y);
            width = xmax - xmin; height = ymax - ymin;    % rect width and height
            if ~width || ~height
                fprintf('Invalid match area - disregarding match\n');
                result.classes(end) = [];
                break;
            end
            rect = [xmin ymin width height];
            if display
                figure(1);
                subplot_tight(2,2,1,[0.02 0.01]);
                vl_plotframe([match_image.matches.f2]);
                rectangle('Position', rect, 'EdgeColor', 'r');
                figure(1) ;
                subplot_tight(2,2,2,[0.02 0.01]);
                visualindex_plot_matches(match_image.matches, match_image.image, im, match_image.sz, sz) ;
            end

            match.rectangle.top = ymax; match.rectangle.left = xmin;
            match.rectangle.bottom = ymin; match.rectangle.right = xmax;
            match.rectangle.width = width; match.rectangle.height = height;
        elseif ellipse_method
            % load the ellipse of the database image
            region_file = fullfile(conf.object_region_dir, [best_match.id '-weightedregion.mat']);
            if ~exist(region_file, 'file')
                fprintf('ERROR: No region file\n');
                break
            end
            t = load(region_file);
            fields = fieldnames(t);
            if isempty(fields);
                region = [];
                fprintf('ERROR: No region field\n');
                break
            else
                region = t.(fields{1});
            end
            clear t;
            % transform the region to the query image domain
            H = [ match_image.matches.A match_image.matches.T; 0 0 1];
            region_query(1:3) = H*[region(1:2); 1]; % x, y pos
            region_query_cov = inv( match_image.matches.A')*[region(3) region(4); region(4) region(5)]*inv( match_image.matches.A);
            region_query(3:5) = [region_query_cov(1,1); region_query_cov(1,2); region_query_cov(2,2)];
            if display
                figure(1)
                subplot_tight(2,2,1,[0.02 0.01]);
                vl_plotframe([match_image.matches.f2]);
                vl_plotframe(region_query, 'Color', 'magenta');
                figure(1) ;
                subplot_tight(2,2,2,[0.02 0.01]);
                visualindex_plot_matches(match_image.matches, match_image.image, im, match_image.sz, sz) ;
            end
            match.ellipse = region_query;
        elseif hull_method
            % load the ellipse of the database image
            region_file = fullfile(conf.object_region_dir, [best_match.id '-convhullkmeans.mat']);
            if ~exist(region_file, 'file')
                fprintf('ERROR: No region file\n');
                break
            end
            t = load(region_file);
            fields = fieldnames(t);
            if isempty(fields);
                hull = [];
                fprintf('ERROR: No hull field\n');
                break
            else
                hull = t.(fields{1});
            end
            clear t;
            % transform hull on to query image
            H = [ match_image.matches.A match_image.matches.T; 0 0 1];
            X_hull = [hull'; ones(1, size(hull,1))];
            X_query = H*X_hull;
            hull_query = X_query(1:2,:)';
            % hull max is edge of image
            h = size(match_image.image,1); w = size(match_image.image,2);
            hull_query(hull_query(:,1) > w,1) = w;
            hull_query(hull_query(:,1) < 0,1) = 0;
            hull_query(hull_query(:,2) > h,2) = h;
            hull_query(hull_query(:,2) < 0,2) = 0;
            if display
                figure(1)
                subplot_tight(2,2,1,[0.02 0.01]);
                vl_plotframe([match_image.matches.f2]); hold on;
                plot(hull_query(:,1),hull_query(:,2),'r-', 'LineWidth', 2); hold off;
                figure(1) ;
                subplot_tight(2,2,2,[0.02 0.01]);
                visualindex_plot_matches(match_image.matches, match_image.image, im, match_image.sz, sz) ;
            end
            match.hull = hull_query;
        end
        
        
        match.path = match_image.path;
        match.class = match_image.class;

%         add match to results
        result.matches{end+1} = match;
        
        fprintf('Added to matches! \n');
        fprintf(log_file, 'Added to matches! \n');
        
%         add rectangle of match to exclusion region
        if rect_method
            exclusion_matrix(end+1,:) = rect;
        end
        
        if length(result.matches) >= max_objects
            fprintf('Search stopped as max_objects hit\n');
            fprintf(log_file, 'Search stopped as max_objects hit\n');
            break            
        end
        
        pass_number = pass_number + 1;
        fprintf(log_file, 'Looking for another object...\n');
        
    end
    
    fprintf('Query complete\n');
    fprintf(log_file, 'Query complete\n');
    
    fclose(log_file);