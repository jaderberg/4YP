% Max Jaderberg 28/11/11

function result = demo_mongo_getobjects(args)
%     Returns the name, link and rectangle coordinates for object in image

    import com.mongodb.BasicDBObject;
    import org.bson.types.ObjectId;

    imagePath = args.image_path;
    display = 0;
    if isfield(args, 'display')
        display = args.display;
    end
    
    figures = 1;
    
    % setup VLFeat
    run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;
    
%     Get the database collection + configuration file
    [conf, coll] = mongo_db_creator();
    
%     Either load or create the histograms and ids
    if exist(fullfile(conf.modelDataDir, 'histograms.mat'), 'file') 
%         assume ids and vocab files are present
        fprintf('Loading histograms in %s\n', conf.modelDataDir);
        m = load(fullfile(conf.modelDataDir, 'histograms.mat'));
        histograms = m.histograms;
        fprintf('Loading ids in %s\n', conf.modelDataDir);
        m = load(fullfile(conf.modelDataDir, 'ids.mat'));
        ids = m.ids;
        fprintf('Loading vocab in %s\n', conf.modelDataDir);
        vocab = load(fullfile(conf.modelDataDir, 'vocab.mat'));
        clear m;
    else
        fprintf('Beginning visual index building...\n');
        [histograms ids vocab] = build_index(coll, conf, 'numWords', conf.numWords);
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
    
    best_match = image_query(im, histograms, ids, vocab, conf, coll);
    
    db_im = coll.findOne(BasicDBObject('_id', ObjectId(best_match.id)));
    fprintf('Object found: %s\n', db_im.get('class'));
    db_size = db_im.get('size');
    match_image.sz = [db_size.get('width') db_size.get('height')];
    match_image.path = fullfile(db_im.get('directory'), db_im.get('name'));
    match_image.image = imread(match_image.path);
    match_image.matches = best_match.match;
    match_image.class = db_im.get('class');
    
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
        visualindex_plot_matches([], match_image.matches, match_image.image, im, match_image.sz, sz) ;
    end


    match.rectangle.top = ymax; match.rectangle.left = xmin;
    match.rectangle.width = width; match.rectangle.height = height;
    match.path = match_image.path;

    fprintf('Query complete!\n');
    
    result = match_image;
    
    
    
    
    
    