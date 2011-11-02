% Max Jaderberg 2011

function result = demo_getobjects(args)
%     Returns the name, link and rectangle coordinates for object in image
    imagePath = args.image_path;
    display = 0;
    if isfield(args, 'display')
        display = args.display;
    end
    
    % setup VLFeat
    run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;

    % build a list of images by sourcing a standard dataset
    [conf, imdb] = db_helper() ;
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
        figure(1) ; clf ;
        imagesc(im) ; title(sprintf('Query: %s', imagePath)) ;
        axis image off ; drawnow ;
    end
    
%     Get matches
    [ids, scores, matches] = visualindex_query(model, im) ;

    match_image.id = find(imdb.images.id == ids(1));
    match_image.sz = imdb.images.size(:, match_image.id);
    match_image.path = fullfile(imdb.dir, imdb.images.name{match_image.id});
    match_image.image = imread(match_image.path);
    match_image.matches = matches{1};
    
    if display
    %     Plot matched image
        figure(2); clf;
        imagesc(match_image.image) ; title(sprintf('Best match: %s', match_image.path)) ;
        axis image off ; drawnow ;
    end

%     Plot matches on query image and bounding rectangle
    match_coords_x = match_image.matches.f2(1,:);
    match_coords_y = match_image.matches.f2(2,:);
    xmin = min(match_coords_x); ymin = min(match_coords_y); xmax = max(match_coords_x); ymax = max(match_coords_y);
    width = xmax - xmin; height = ymax - ymin;    % rect width and height
    rect = [xmin ymin width height];
    if display
        figure(1);
        vl_plotframe([match_image.matches.f2]);
        rectangle('Position', rect, 'EdgeColor', 'r');
        figure(3) ; clf ;
        visualindex_plot_matches(model, match_image.matches, match_image.image, im, match_image.sz, sz) ;
    end
    
    
    result.query_image.path = imagePath;
    result.query_image.sz = sz;
    result.match.rectangle.top = ymax; result.match.rectangle.left = xmin;
    result.match.rectangle.width = width; result.match.rectangle.height = height;
    result.match.path = match_image.path;
    
    fprintf('Query Complete!');
    
    
    
    