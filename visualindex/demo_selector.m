% Max Jaderberg 2011

function done = demo_selector()
    % Demonstrate visualindex on a subsection of an image
    
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
    
%   Select random image for querying
    i = randi(length(selTest));
    
    imagePath = fullfile(imdb.dir, imdb.images.name{selTest(i)}) ;
    thumbPath = fullfile(conf.thumbDir, imdb.images.name{selTest(i)}) ;

    fprintf('Query image %s\n', imagePath) ;
    im = imread(imagePath) ;
    thumb = imread(thumbPath) ;
    sz = [size(im,2); size(im,1)] ;

    figure(1) ; clf ;
    
%   Select sub image to search in    
    [sub_x, sub_y, im_sub, sub_rect] = imcrop(im);
    
    figure(1); clf;
    imagesc(im) ; title(sprintf('query %d', i)) ;
    rectangle('Position', sub_rect, 'EdgeColor', 'r');
    axis image off ; drawnow ;
    
    
%     Now query on the sub image...
    [ids, scores, matches] = visualindex_query(model, im_sub) ;

    figure(2) ; clf ;
    for k = 1:min(6, length(ids))
      vl_tightsubplot(6,k,'box','outer') ;
      ii = find(imdb.images.id == ids(k)) ;
      sz_{k} = imdb.images.size(:, ii) ;
      thumb_{k} = imread(fullfile(conf.thumbDir, imdb.images.name{ii})) ;
      imagesc(thumb_{k}) ;
      axis image off ;
      title(sprintf('rank:%d score:%g id:%d', k, full(scores(k)), ids(k))) ;
    end

    figure(4) ; clf ;
    visualindex_plot_matches(model, matches{1}, thumb_{1}, thumb, sz_{1}, sz, sub_rect(1:2)) ;

    fprintf('Query finished!\n');
    done = 'Done';
    
    