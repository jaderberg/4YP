% Max Jaderberg 28/11/11

function [result frames descrs] = image_query( im, histograms, ids, vocab, conf, coll, varargin )
%IMAGE_QUERY returns the matched images from the query

    %profile on;

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
        [frames descrs] = visualindex_get_features(im);
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
    
    
    % compute histogram-based score
    fprintf('Getting histogram-based matches\n');
    scores = tf_idf_scores(histogram, histograms) ;
    clear histogram histograms;

    % apply geometric verification to the top matches
    [scores, perm] = sort(scores, 'descend') ;
    
%     Spatially verify the top matches until we get a spatial match!
    for i=1:opts.depth
        perm_ind = perm(i);
        match_id = ids{perm_ind};
%         Get the words and frames for potential match
        db_im = coll.findOne(BasicDBObject('_id', ObjectId(match_id)));
        
%         if the potential match is in the excluded classes set, continue
        match_class = db_im.get('class');
        if ~isempty(match_class)
            if find(ismember(opts.excludeClasses, match_class)==1)
                fprintf('Potential match is in excluded classes set (%s)\n', db_im.get('class'));
                if i == opts.depth
                    result.score = 0;
                    return
                else
                    continue
                end
            end
        else
            fprintf('Potential match has no class - ignoring it\n');
            if i == opts.depth
                result.score = 0;
                return
            else
                scores(i) = 0; 
                continue
            end
        end
        
        match_words = load_words(match_id, conf);
        match_frames = load_frames(match_id, conf);
        [match_score, matches(i)] = verify(match_frames, match_words, ...
                                   frames, words, ...
                                   size(im)) ;
        fprintf('Found match (%s) with %d inliers - ', db_im.get('name'), match_score);
%         Add tf-idf to spatial score to avoid ties
        scores(i) = match_score + scores(i);
%        If there are enough inliers (the score) we have found a spatially
%        verified match
        if match_score >= 10
%             this is definitely a match
            fprintf('thats good enough!\n');
            break
        else
            fprintf('not good enough, looking for another...\n');
            clear db_im db_model match_words match_frames match_score match perm_ind match_id;
        end
        
    end
    
    [best_score ind] = max(scores(1:opts.depth));
    
    match_perm = perm(ind);
    result.id = ids{match_perm};
    result.score = full(best_score);
    result.match = matches(ind);
    
    %profile viewer;
    
end

%---------------------------------------------------------------------
function scores = tf_idf_scores(histogram, histograms)
%     The histogram scores
    scores = histogram' * histograms ;
end

% --------------------------------------------------------------------
function [score, matches] = verify(f1,w1,f2,w2,s2)
% --------------------------------------------------------------------
    % The geometric verfication is a simple RANSAC affine matcher. It can
    % be significantly improved.

    % find the features that are mapped to the same visual words
    [drop,m1,m2] = intersect(w1,w2) ;
    numMatches = length(drop) ;

    % get the 2D coordinates of these features in homogeneous notation
    X1 = f1(1:2, m1) ;
    X2 = f2(1:2, m2) ;
    X1(3,:) = 1 ;
    X2(3,:) = 1 ;

    thresh = max(max(s2)*0.02, 10) ;

    % RANSAC
    randn('state',0) ;
    rand('state',0) ;
    numRansacIterations = 500 ;
    for t = 1:numRansacIterations
      %fprintf('RANSAC iteration %d of %d\r', t, numRansacIterations) ;
      % select a subset of 3 matched features at random
      subset = vl_colsubset(1:numMatches, 3) ;

      % subtract the first one from the other two and then compute affine
      % transformation (note the small regularization term).
      u1 = X1(1:2,subset(3)) ;
      u2 = X2(1:2,subset(3)) ;
      A{t} = (X2(1:2,subset(1:2)) - [u2 u2]) / ...
             (X1(1:2,subset(1:2)) - [u1 u1] + eye(2)*1e-5) ;
      T{t} = u2 - A{t} * u1 ;

      % the score is the number of inliers
      X2_ = [A{t} T{t} ; 0 0 1] * X1 ;
      delta = X2_ - X2 ;
      ok{t} = sum(delta.*delta,1) < thresh^2 ;
      score(t) = sum(ok{t}) ;
    end

    [score, best] = max(score) ;
    matches.A = A{best} ;
    matches.T = T{best} ;
    matches.ok = ok{best} ;
    matches.f1 = f1(:, m1(matches.ok)) ;
    matches.f2 = f2(:, m2(matches.ok)) ;

end

