% Max Jaderberg 28/11/11

function result = demo_mongo_getobjects(args)
%     Returns the name, link and rectangle coordinates for object in image
%     Uses the 5k oxford dataset at time of writing 29/11/11

    

    %javaaddpath('/Users/jaderberg/Sites/4YP/visualindex/oxford_dataset/mongo-2.7.2.jar')

    
        
    import com.mongodb.BasicDBObject;
    import org.bson.types.ObjectId;
    

    imagePath = args.image_path;
    display = 0;
    if isfield(args, 'display')
        display = args.display;
    end
    
    if ~isfield(args, 'log_file')
        args.log_file = 'log.txt';
    end
    log_file = fopen(args.log_file, 'w');
    
    figures = 1;
    
    
    
    % setup VLFeat
    run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;
    
    
%     Get the database collection + configuration file
    [conf, coll] = mongo_db_creator();
    
    
%     See if the global variables exist
    global histograms
    global ids
    global vocab
    
    
    if isempty(histograms) || isempty(ids) || isempty(vocab)
    %     Either load or create the histograms and ids
        if exist(fullfile(conf.modelDataDir, 'histograms.mat'), 'file') 
    %         assume ids and vocab files are present
            fprintf('Loading histograms in %s\n', conf.modelDataDir);
            fprintf(log_file, 'Loading histograms in %s\n', conf.modelDataDir);
            m = load(fullfile(conf.modelDataDir, 'histograms.mat'));
            histograms = m.histograms;
            fprintf('Loading ids in %s\n', conf.modelDataDir);
            fprintf(log_file, 'Loading ids in %s\n', conf.modelDataDir);
            m = load(fullfile(conf.modelDataDir, 'ids.mat'));
            ids = m.ids;
            fprintf('Loading vocab in %s\n', conf.modelDataDir);
            fprintf(log_file, 'Loading vocab in %s\n', conf.modelDataDir);
            vocab = load(fullfile(conf.modelDataDir, 'vocab.mat'));
            clear m;
        else
            fprintf('Beginning visual index building...\n');
            fprintf(log_file, 'Beginning visual index building...\n');
            [histograms ids vocab] = build_index(coll, conf, 'numWords', conf.numWords);
        end
    end
    
    %     Read Image
    fprintf('Query image %s\n', imagePath) ;
    fprintf(log_file, 'Query image %s\n', imagePath) ;
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
    
    fprintf(log_file, 'Starting match process...\n');
    
    while pass_number < max_objects*max_tries_per_object
        
        [best_match frames descrs] = image_query(im, histograms, ids, vocab, conf, coll, 'excludeClasses', result.classes,'exclude', exclusion_matrix,'frames', frames, 'descrs', descrs);

        fprintf('Match has a score of %d. ', best_match.score);
        fprintf(log_file, 'Match has a score of %d. ', best_match.score);
        if best_match.score < 10
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
        match_image.path = fullfile(db_im.get('directory'), db_im.get('name'));
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
            visualindex_plot_matches([], match_image.matches, match_image.image, im, match_image.sz, sz) ;
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
    
   
    
    
    
    
    
    