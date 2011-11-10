% Max Jaderberg 2011

function result = demo_getobjects(args)
%     Returns the name, link and rectangle coordinates for object in image
    imagePath = args.image_path;
    display = 0;
    if isfield(args, 'display')
        display = args.display;
    end
    
    figures = 1;
    
    % setup VLFeat
    run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;

    % build a list of images by sourcing a standard dataset
    [conf, imdb] = db_full_helper() ;
    selTrain = find(imdb.images.set == imdb.sets.TRAIN) ;
    selTest = find(imdb.images.set == imdb.sets.TEST) ;
    images = imdb.images.name(selTrain) ;
    ids = imdb.images.id(selTrain) ;
    images = cellfun(@(x) fullfile(imdb.dir,x),images, 'uniformoutput',0) ;

    % ------------------------------------------------------------------
    %                                                        Build index
    % ------------------------------------------------------------------

    if exist(conf.modelPath, 'file')
        fprintf('Loading index found at %s\n', conf.modelPath) ;
        model = load(conf.modelPath) ;
    else
        fprintf('Creating a new index at %s\n', conf.modelPath) ;
        model = visualindex_build(images, ids, 'numWords', conf.numWords) ;
        save(conf.modelPath, '-STRUCT', 'model') ;
    end
    
%     Read Image
    fprintf('Query image %s\n', imagePath) ;
    im = imread(imagePath) ;
    sz = [size(im,2); size(im,1)] ;

    if display
    %     Plot image
        figure(figures) ; clf ; figures = figures + 1;
        imagesc(im) ; title(sprintf('Query: %s', imagePath)) ;
        axis image off ; drawnow ;
    end
    
    
    max_objects = 3;
    max_tries_per_object = 2;
    
    result.query_image.path = imagePath;
    result.query_image.sz = sz;
    result.matches = {};
    result.classes = [];
    
    exclusion_matrix = [];
    pass_number = 1;
    current_tries = 0;
    
    while pass_number < max_objects*max_tries_per_object
       
        [ids, scores, matches] = visualindex_query(model, im, 'exclude', exclusion_matrix) ;
        
        score = full(scores(1));
        fprintf('Match has %d inliers. ', score);
        if scores(1) < 8
%             There's no recognisable object in this image :(
            fprintf('Not enough inliers - no objects found\n');
            return
        end
        
        match_image.id = find(imdb.images.id == ids(1));
        match_image.class = imdb.images.class(match_image.id);
        
        if find(result.classes == match_image.class)
%             This object has already been found in the image
            fprintf('The recognised object has already been found\n');
            current_tries = current_tries + 1;
            if current_tries >= max_tries_per_object
                fprintf('Search stopped as no new object found\n');
                break
            else
                continue
            end
        else
            result.classes(end+1) = match_image.class;
        end
        
        match_image.sz = imdb.images.size(:, match_image.id);
        match_image.path = fullfile(imdb.dir, imdb.images.name{match_image.id});
        match_image.image = imread(match_image.path);
        match_image.matches = matches{1};
        
        if display
%             Plot matched image
            figure(figures); clf; figures = figures + 1;
            imagesc(match_image.image) ; title(sprintf('Best match: %s', match_image.path)) ;
            axis image off ; drawnow ;
        end

%         Plot matches on query image and bounding rectangle
        match_coords_x = match_image.matches.f2(1,:);
        match_coords_y = match_image.matches.f2(2,:);
        xmin = min(match_coords_x); ymin = min(match_coords_y); xmax = max(match_coords_x); ymax = max(match_coords_y);
        width = xmax - xmin; height = ymax - ymin;    % rect width and height
        rect = [xmin ymin width height];
        if display
            figure(1);
            vl_plotframe([match_image.matches.f2]);
            rectangle('Position', rect, 'EdgeColor', 'r');
            figure(figures) ; clf ; figures = figures + 1;
            visualindex_plot_matches(model, match_image.matches, match_image.image, im, match_image.sz, sz) ;
        end


        match.rectangle.top = ymax; match.rectangle.left = xmin;
        match.rectangle.width = width; match.rectangle.height = height;
        match.path = match_image.path;

%         add match to results
        result.matches{end+1} = match;
        
        fprintf('Added to matches! \n');
        
%         add rectangle of match to exclusion region
        exclusion_matrix(end+1,:) = rect;
        
        if length(result.matches) >= max_objects
            fprintf('Search stopped as max_objects hit\n');
            break            
        end
        
        pass_number = pass_number + 1;
    end
    
    
    fprintf('Query Complete - object(s) found\n');
    
    
    
    