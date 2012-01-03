% Max Jaderberg 3/1/12

function [result frames descrs] = image_query2(im, class_histograms, classes, vocab, conf, coll, varargin)
% A new implementation of image querying using super histograms

    import com.mongodb.BasicDBObject;
    import org.bson.types.ObjectId;

    opts.exclude = [];  
    opts.depth = 10;
    opts.frames = []; opts.descrs = [];
    opts.excludeClasses = {};
    opts = vl_argparse(opts, varargin);
    
    frames = opts.frames; descrs = opts.descrs;
    clear opts.frames opts.descrs;
    
%     Get the features from the query image
    if isempty(frames)
        fprintf('Getting features...\n');
        [frames descrs] = visualindex_get_features([], im);
    else
        fprintf('Already got features!\n');
    end
    
    % Delete frames (and associated descrs) that are in exclusion regions
    if ~isempty(opts.exclude)
    %     For each exclusion region (row of exclusion matrix)
        for e = 1:size(opts.exclude, 1)
            new_frames = []; new_descrs = single([]);
            exclusion_region = opts.exclude(e,:);
    %         Exclusion region is defined by a rectangle
            xmin = exclusion_region(1); ymin = exclusion_region(2); 
            xmax = xmin + exclusion_region(3); ymax = ymin + exclusion_region(4);
            for f = 1:size(frames, 2)
                fx = frames(1,f); fy = frames(2,f);
                if fx < xmin || fy < ymin || fy > ymax || fx > xmax
                    new_frames(:,end+1) = frames(:,f);
                    new_descrs(:,end+1) = descrs(:,f);
                end
            end
            frames = new_frames;
            descrs = new_descrs;
        end
    end
    
%     Get the words
    fprintf('Getting words...\n');
    fake_model.vocab = vocab;
    words = visualindex_get_words(fake_model, descrs);
    
%     Get the histogram
    fprintf('Getting histogram...\n');
    histogram = visualindex_get_histogram(fake_model, words);
%     times by tf-idf weights
    histogram = histogram.*vocab.weights;
    
%     REMOVE THIS ONCE NORMALIZATION IS DONE IN THE INDEXING STAGE!!!!
    for i=1:length(classes)
        class_histograms(:,i) = (1/sum(class_histograms(:,i)))*class_histograms(:,i);
    end
%     -=-=-=-=-=--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    
%     Class match score
    scores = full(histogram' * class_histograms) ;
    
    [scores, perm] = sort(scores, 'descend') ;
    
    for i=1:length(scores)
        fprintf('%s : %f\n', classes{perm(i)}, scores(i));
    end