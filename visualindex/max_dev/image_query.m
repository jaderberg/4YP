% Max Jaderberg 28/11/11

function result = image_query( im, histograms, ids, vocab, conf, coll, varargin )
%IMAGE_QUERY returns the matched images from the query

    import com.mongodb.BasicDBObject;
    import org.bson.types.ObjectId;

    opts.exclude = [];  
    opts = vl_argparse(opts, varargin);
    
%     Get the features from the query image
    fprintf('Getting features...\n');
    [frames descrs] = visualindex_get_features([], im);
    
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
    clear descrs;
    
%     Get the histogram
    fprintf('Getting histogram...\n');
    histogram = visualindex_get_histogram(fake_model, words);
    
    
    % compute histogram-based score
    fprintf('Getting histogram-based matches\n');
    scores = histogram' * histograms ;
    clear histogram histograms;

    % apply geometric verification to the top matches
    [scores, perm] = sort(scores, 'descend') ;
    
%     Spatially verify the top matches until we get a spatial match!
    for i=1:length(scores)
        perm_ind = perm(i);
        match_id = ids{perm_ind};
%         Get the words and frames for potential match
        db_im = coll.findOne(BasicDBObject('_id', ObjectId(match_id)));
        db_model = db_im.get('model');
        match_words = eval(db_model.get('words'));
        match_frames = eval(db_model.get('frames'));
        [match_score, match] = verify(match_frames, match_words, ...
                                   frames, words, ...
                                   size(im)) ;
        fprintf('Found match with %d inliers - ', match_score);
%        If there are enough inliers (the score) we have found a spatially
%        verified match
        if match_score > 15
%             this is definitely a match
            fprintf('thats good enough!\n');
            break
        else
            fprintf('not good enough, looking for another...\n');
            clear db_im db_model match_words match_frames match_score match perm_ind match_id;
        end
        
    end
    
    result.id = match_id;
    result.score = match_score;
    result.match = match;
    
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

