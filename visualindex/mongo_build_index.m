% Max Jaderberg

function model_coll = mongo_build_index(coll, conf, varargin)
% This creates the visual index for the dataset

    conf.dataDir = [conf.dataDir '/'];


    javaaddpath('mongo-2.7.2.jar')

    import com.mongodb.Mongo;
    import com.mongodb.DB;
    import com.mongodb.DBCollection;
    import com.mongodb.BasicDBObject;
    import com.mongodb.DBObject;
    import com.mongodb.DBCursor;
    import org.bson.types.ObjectId;

    opts.numWords = 10000 ;
    opts.numKMeansIterations = 20 ;
    opts = vl_argparse(opts, varargin) ;
    
    randn('state',0) ;
    rand('state',0) ;

    model.rerankDepth = 40 ;
    model.vocab.size = opts.numWords ;
    model.index = struct ;
    
%     We are going to create a model database entry
    model_coll = coll.getDB().getCollection('model');
    
    model_db = BasicDBObject();
    model_db.put('name', 'metadata');
    model_db.put('rerank_depth', model.rerankDepth);
    model_coll.save(model_db);
    
    vocab = BasicDBObject();
    vocab.put('name', 'vocab');
    vocab.put('size', opts.numWords);
    

    % --------------------------------------------------------------------
    %                                              Extract visual features
    % --------------------------------------------------------------------
    % Extract SIFT features from each image.

    % read features
    num_images = coll.find().count();
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
    
    
    save([conf.dataDir 'model-index-frames.mat'], 'frames') ;
    save([conf.dataDir 'model-index-descrs.mat'], '-v7.3', 'descrs') ;
    save([conf.dataDir 'model-index-ids.mat'], 'ids') ;
    clear frames descrs ids im_frames im_descrs;

    % --------------------------------------------------------------------
    %                                                  Large scale k-means
    % --------------------------------------------------------------------
    % Quantize the SIFT features to obtain a visual word vocabulary.
    % Implement a fast approximate version of K-means by using KD-Trees
    % for quantization.


    model_index = load([conf.dataDir 'model-index-descrs.mat']);
    model_index_descrs = model_index.descrs;
    clear model_index;
    descrs = vl_colsubset(cat(2,model_index_descrs{:}), opts.numWords * 15) ;
    clear model_index_descrs;

    [model.vocab.centers, model.vocab.tree] = ...
        annkmeans(descrs, opts.numWords, 'verbose', true) ;
    
    clear descrs;
    
    
    vocab.put('centers', serialize(model.vocab.centers));
    vocab.put('tree', serialize(model.vocab.tree));

    % --------------------------------------------------------------------
    %                                                           Histograms
    % --------------------------------------------------------------------
    % Compute a visual word histogram for each image, compute TF-IDF
    % weights, and then reweight the histograms.

    model_index = load([conf.dataDir 'model-index-ids.mat']);
    model_index_ids = model_index.ids;
    model_index = load([conf.dataDir 'model-index-descrs.mat']);
    model_index_descrs = model_index.descrs;
    clear model_index;

    words = cell(1, numel(model_index_ids)) ;
    histograms = cell(1,numel(model_index_ids)) ;
    for t = 1:length(model_index_ids)
      words{t} = visualindex_get_words(model, model_index_descrs{t}) ;
      histograms{t} = sparse(double(words{t}),1,...
                             ones(length(words{t}),1), ...
                             model.vocab.size,1) ;
    end
    clear model_index_descrs;
    
    save([conf.dataDir 'model-index-words.mat'], 'words') ;
    
    model_index_histograms = cat(2, histograms{:}) ;
    save([conf.dataDir 'model-index-histograms.mat'], 'model_index_histograms') ;

    clear words histograms ;

    % compute IDF weights
    model.vocab.weights = log((size(model_index_histograms,2)+1) ...
                              ./  (max(sum(model_index_histograms > 0,2),eps))) ;
                          
    
    vocab.put('weights', serialize(model.vocab.weights));
                          
                          
    % weight and normalize histograms
    for t = 1:length(model_index_ids)
      h = model_index_histograms(:,t) .*  model.vocab.weights ;
      model_index_histograms(:,t) = h / norm(h) ;
      image = coll.findOne(BasicDBObject('_id', ObjectId(model_index_ids{t})));
      im_model = image.get('model');
      im_model.put('histogram', serialize(model_index_histograms(:,t), 3));
      coll.save(image);
    end
    
    vcab = model.vocab;
    save([conf.dataDir 'model-vocab.mat'], '-STRUCT', 'vcab') ;
    clear vcab;
    
    clear model;
    model_coll.save(model_db);
    model_coll.save(vocab);
    