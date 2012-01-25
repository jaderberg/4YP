% Max Jaderberg 8/1/12

function result = demo_wiki_get_objects(args)
% Returns the matched object and region of matchings. Must run
% preprocess_solution.m once before this works. Also the mongodb java
% library must be imported by running javaaddpath('mongo-2.7.2.jar')

%--------------------------------------------------------------------------
% SET THIS TO THE ROOT_DIR USED IN preprocess_solution.m
    ROOT_DIR = '/Volumes/4YP/wikilist_visualindex2';
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
    
    figures = 1;

    % setup VLFeat
    run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;
    
%     load config file
    try
        conf = load(fullfile(ROOT_DIR, 'conf.mat'));
    catch err
        fprintf('ERROR: could not find conf.mat. Make sure preprocess_solution.m has been run.\n');
        result = 0;
        return
    end
    
%     load mongo collection
    coll = mongo_get_collection();
    
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
        m = load(fullfile(conf.modelDataDir, 'histograms.mat'));
        histograms = m.histograms;
        fprintf('Loading ids from %s\n', conf.modelDataDir);
        fprintf(log_file, 'Loading ids from %s\n', conf.modelDataDir);
        m = load(fullfile(conf.modelDataDir, 'ids.mat'));
        ids = m.ids;
        fprintf('Loading vocab from %s\n', conf.modelDataDir);
        fprintf(log_file, 'Loading vocab from %s\n', conf.modelDataDir);
        vocab = load(fullfile(conf.modelDataDir, 'vocab.mat'));
        fprintf('Loading super histograms...\n');
        m = load(fullfile(conf.modelDataDir, 'class_names.mat'));
        class_names = m.class_names;
%         m = load(fullfile(conf.modelDataDir, 'class_histograms.mat'));
%         class_hists = m.super_class_histograms;
%         m = load(fullfile(conf.modelDataDir, 'classes_useful_hists.mat'));
%         classes_useful_hists = m.classes_useful_hists;
        clear m;
    end

    %     Read Image
    fprintf('Querying image %s\n', imagePath) ;
    fprintf(log_file, 'Querying image %s\n', imagePath) ;
    im = imread(imagePath) ;
    sz = [size(im,2); size(im,1)] ;

    if display
    %     Plot image
        figure(figures) ; clf ; figures = figures + 1;
        imagesc(im) ; title(sprintf('Query: %s', imagePath)) ;
        axis image off ; drawnow ;
    end
    
    %     Now do multiple object matching!
    max_objects = 2;
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
        
        [best_match frames descrs] = image_query(im, histograms, ids, vocab, conf, coll, 'excludeClasses', result.classes,'exclude', exclusion_matrix,'frames', frames, 'descrs', descrs);
        %[best_match frames descrs] = image_query2(im, class_hists, class_names, vocab, conf, coll, 'excludeClasses', result.classes,'exclude', exclusion_matrix,'frames', frames, 'descrs', descrs, 'pass_number', pass_number);

        fprintf('Match has a score of %d. ', best_match.score);
        fprintf(log_file, 'Match has a score of %d. ', best_match.score);
        if best_match.score < 5
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
        match_image.path = db_im.get('path');
        match_image.image = imread(match_image.path);
        match_image.matches = best_match.match;
        
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
            visualindex_plot_matches(match_image.matches, match_image.image, im, match_image.sz, sz) ;
        end

        match.rectangle.top = ymax; match.rectangle.left = xmin;
        match.rectangle.width = width; match.rectangle.height = height;
        match.path = match_image.path;
        match.class = match_image.class;

%         add match to results
        result.matches{end+1} = match;
        
        fprintf('Added to matches! \n');
        fprintf(log_file, 'Added to matches! \n');
        
%         add rectangle of match to exclusion region
        exclusion_matrix(end+1,:) = rect;
        
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
    
   

    