% Max Jaderberg 2011

function model = demo_selector(model)
    % Demonstrate visualindex on a subsection of an image
    
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
        if ~exist('model', 'var')
            fprintf('Loading index found at %s\n', conf.modelPath) ;
            model = load(conf.modelPath) ;
        end
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

%         Plot affine transformed rectangle to matched image
    match_image.id = find(imdb.images.id == ids(1));
    match_image.sz = imdb.images.size(:, match_image.id);
    match_image.path = fullfile(imdb.dir, imdb.images.name{match_image.id});
    match_image.image = imread(match_image.path);
    match_image.matches = matches{1};
    figure(3); clf;
    imagesc(match_image.image) ; title(sprintf('Best match: %s', match_image.path)) ;
    axis image off ; drawnow ;
    rect_corners = [sub_rect(1) sub_rect(1) sub_rect(1)+sub_rect(3) sub_rect(1)+sub_rect(3); sub_rect(2) sub_rect(2)+sub_rect(4) sub_rect(2) sub_rect(2)+sub_rect(4); 1 1 1 1];
%     Inverse of an affine transform
%     (http://en.wikipedia.org/wiki/Affine_transformation)
    A_ = inv(match_image.matches.A); 
    H = [A_ -1*A_*match_image.matches.T; 0 0 1];
    rect_corners = H*rect_corners;
    line([rect_corners(1,1) rect_corners(1,1) rect_corners(1,4) rect_corners(1,4) ; rect_corners(1,2) rect_corners(1,3) rect_corners(1,2) rect_corners(1,3) ], [rect_corners(2,1) rect_corners(2,1) rect_corners(2,4) rect_corners(2,4) ; rect_corners(2,2) rect_corners(2,3) rect_corners(2,2) rect_corners(2,3) ], 'color', 'r');
    vl_plotframe([match_image.matches.f1]) ;
    axis image off ; drawnow ;

    
    fprintf('Query finished!\n');
    
    
    