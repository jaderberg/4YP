% Max Jaderberg

function model = mongo_build_index(coll, varargin)
% This creates the visual index for the dataset

    javaaddpath('mongo-2.7.2.jar')

    import com.mongodb.Mongo;
    import com.mongodb.DB;
    import com.mongodb.DBCollection;
    import com.mongodb.BasicDBObject;
    import com.mongodb.DBObject;
    import com.mongodb.DBCursor;
    import org.bson.types.ObjectId;

    opts.numWords = 100 ;
    opts.numKMeansIterations = 20 ;
    opts = vl_argparse(opts, varargin) ;
    
    randn('state',0) ;
    rand('state',0) ;

    model.rerankDepth = 40 ;
    model.vocab.size = opts.numWords ;
    model.index = struct ;

    % --------------------------------------------------------------------
    %                                              Extract visual features
    % --------------------------------------------------------------------
    % Extract SIFT features from each image.

    % read features
    num_images = coll.find().count();
    num_images = 4;
    frames = cell(1,num_images) ;
    descrs = cell(1,num_images) ;
    for i = 1:num_images
        image = coll.find().skip(i-1).limit(1).toArray.get(0);
        ids{i} = image.get('_id').toString.toCharArray';
        fprintf('Adding image %s (%d of %d)\n', ...
              image.get('name'), i, num_images) ;
        im = imread(fullfile(image.get('directory'), image.get('name'))) ;
        [im_frames,im_descrs] = visualindex_get_features(model, im) ;
        im_model = BasicDBObject();
        im_model.put('frames', serialize(im_frames,3));
        im_model.put('descrs', serialize(im_descrs,3));
        image.put('model', im_model);
        coll.save(image);
        frames{i} = im_frames; descrs{i} = im_descrs;
    end
    model.index.frames = frames ;
    model.index.descrs = descrs ;
    model.index.ids = ids ;
    clear frames descrs ids ;

    % --------------------------------------------------------------------
    %                                                  Large scale k-means
    % --------------------------------------------------------------------
    % Quantize the SIFT features to obtain a visual word vocabulary.
    % Implement a fast approximate version of K-means by using KD-Trees
    % for quantization.

    E = [] ;
    assign = []  ;
    descrs = vl_colsubset(cat(2,model.index.descrs{:}), opts.numWords * 15) ;
    dist = inf(1, size(descrs,2)) ;

    [model.vocab.centers, model.vocab.tree] = ...
        annkmeans(descrs, opts.numWords, 'verbose', true) ;

    % --------------------------------------------------------------------
    %                                                           Histograms
    % --------------------------------------------------------------------
    % Compute a visual word histogram for each image, compute TF-IDF
    % weights, and then reweight the histograms.

    words = cell(1, numel(model.index.ids)) ;
    histograms = cell(1,numel(model.index.ids)) ;
    for t = 1:length(model.index.ids)
      words{t} = visualindex_get_words(model, model.index.descrs{t}) ;
      histograms{t} = sparse(double(words{t}),1,...
                             ones(length(words{t}),1), ...
                             model.vocab.size,1) ;
    end
    model.index.words = words ;
    model.index.histograms = cat(2, histograms{:}) ;
    clear words histograms ;

    % compute IDF weights
    model.vocab.weights = log((size(model.index.histograms,2)+1) ...
                              ./  (max(sum(model.index.histograms > 0,2),eps))) ;

    % weight and normalize histograms
    for t = 1:length(model.index.ids)
      h = model.index.histograms(:,t) .*  model.vocab.weights ;
      model.index.histograms(:,t) = h / norm(h) ;
      image = coll.findOne(BasicDBObject('_id', ObjectId(model.index.ids{t})));
      im_model = image.get('model');
      im_model.put('histogram', serialize(model.index.histograms(:,t), 3));
      coll.save(image);
    end
    
    