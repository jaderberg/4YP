% Max Jaderberg 28/11/11

function result = demo_mongo_getobjects(args)
%     Returns the name, link and rectangle coordinates for object in image
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
    
    result = image_query(im, histograms, ids, vocab, conf, coll);
    
    
    
    
    