% Max Jaderberg 3/1/12

function [result frames descrs] = image_query2(im, class_histograms, classes, vocab, conf, coll, varargin)
% A new implementation of image querying using super histograms

    import com.mongodb.BasicDBObject;
    import org.bson.types.ObjectId;

    opts.exclude = [];  
    opts.pass_number = 1;
    opts.image_depth = 2;
    opts.class_depth = 3;
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
    
    
%     Class match score
    class_scores = full(histogram' * class_histograms) ;
    
    [class_scores, perm] = sort(class_scores, 'descend') ;
    
%     for the top classes, spatially verify to confirm class and matched
%     region
    spatially_verified = 0;
    if length(class_scores) > opts.class_depth
        class_limit = opts.class_depth;
    else
        class_limit = length(class_scores);
    end
    for i=1:class_limit
        class_name = classes{perm(i)};
        
        if find(ismember(opts.excludeClasses, class_name)==1)
            fprintf('Matched class is in excluded classes set (%s)\n', class_name);
            if i == length(class_scores)
                result.score = 0;
                return
            else
                continue
            end
        end
        
        fprintf('Checking if %s (score: %f)\n', classes{perm(i)}, class_scores(i));

%         load the useful histograms for the class
        temp = load(fullfile(conf.classesDataDir, class_name, 'class_ids.mat'));
        class_images_ids = temp.class_ids;
        temp = load(fullfile(conf.classesDataDir, class_name, 'class_useful_hists.mat'));
        class_useful_hists = temp.class_useful_hists;
        clear temp;
        
        image_scores = full(histogram' * class_useful_hists);
        [image_scores im_perm] = sort(image_scores, 'descend');

%         spatially verify an image
        if opts.image_depth < length(class_images_ids)
            im_limit = opts.image_depth;
        else
            im_limit = length(class_images_ids);
        end
        for j=1:im_limit;
            match_id = class_images_ids{im_perm(j)};
            %         Get the words and frames for potential match
            db_im = coll.findOne(BasicDBObject('_id', ObjectId(match_id)));
            db_model = db_im.get('model');
            match_words = eval(db_model.get('words'));
            match_frames = eval(db_model.get('frames'));
%           -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
%             use only USEFUL words for RANSAC
            useful_words = find(class_useful_hists(:,im_perm(j)) > 0);
            new_words = [];
            for k=1:length(useful_words)
                word_i = find(match_words == useful_words(k));
                if isempty(new_words)
                    new_words = match_words(word_i);
                    new_frames = match_frames(:, word_i);
                else
                    new_words = [new_words match_words(word_i)];
                    new_frames = [new_frames match_frames(:, word_i)];
                end
            end
            match_frames = new_frames; clear new_frames;
            match_words = new_words; clear new_words;
            [match_score, matches(j)] = spatially_verify(match_frames, match_words, ...
                                       frames, words, ...
                                       size(im)) ;
            matches(j).id = match_id;
            fprintf('Found match (%s) with %d inliers - ', db_im.get('name'), match_score);
            %         Add tf-idf to spatial score to avoid ties
            image_scores(j) = match_score + image_scores(j);
            if match_score >= opts.pass_number*5
                fprintf('thats good enough!\n');
                spatially_verified = 1;
                break
            else
                fprintf('not good enough, looking for another...\n');
                clear db_im db_model match_words match_frames match_score match_id matches;        
            end
        end
        
        if spatially_verified
            break
        end
    end
    
    
    
    [best_score ind] = max(image_scores(1:im_limit));
    
    result.score = full(best_score);
    if ~exist('matches', 'var')
        return
    end
    result.match = matches(ind);
    result.id = result.match.id;