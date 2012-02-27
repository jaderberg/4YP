% Max Jaderberg 28/12/11

function [score, matches] = spatially_verify(f1,w1,f2,w2,size,varargin)
    % The geometric verfication is a simple RANSAC affine matcher. It can
    % be significantly improved.

    opts.includeRepeated = 0;
    opts.repeatedScore = 0;
    opts = vl_argparse(opts, varargin);
    
    % find the features that are mapped to the same visual words
    [d1, m1] = ismember(w1, w2);
    [d2, m2] = ismember(w2, w1);
    f1 = f1(:,d1==1);
    w1 = w1(d1==1);
    m1 = m1(d1~=0);
    f2 = f2(:,d2==1);
    w2 = w2(d2==1);
    m2 = m2(d2~=0);
    
    % save originals
    w1o = w1;
    w2o = w2;
    f1o = f1;
    f2o = f2;
        
    

    % insert all duplicate words in all combinations
    [w1 p1] = sort(w1);
    [w2 p2] = sort(w2);
    f1 = f1(:,p1);
    f2 = f2(:,p2);    
    i = 1;
    while i <= length(w1)
        % get the run of same values
        n1 = find(w1==w1(i)); nn1 = length(n1);
        n2 = find(w2==w1(i)); nn2 = length(n2);
        if nn1 == 1 && nn2 == 1
            i = i + 1;
            continue
        end
        % combine n1 and n2 in all ways possible
        wsub = w1(i).*uint32(ones(1,nn1*nn2));
        m = 1;
        for k=1:nn2
            for l=1:nn1
                f1sub(:,m) = f1(:,i-1+l);
                f2sub(:,m) = f2(:,i-1+k);
                m = m + 1;
            end
        end    
        w1 = [w1(1:i-1) wsub w1(i+nn1:end)];
        w2 = [w2(1:i-1) wsub w2(i+nn2:end)];
        f1 = [f1(:,1:i-1) f1sub f1(:,i+nn1:end)];
        f2 = [f2(:,1:i-1) f2sub f2(:,i+nn2:end)];
        clear f1sub f2sub;       
        i = i + length(wsub);        
    end
    w1r = w1;
    w2r = w2;
    f1r = f1;
    f2r = f2;
    w1 = w1o; w2 = w2o; f1 = f1o; f2 = f2o;
    clear w1o w2o f1o f2o;
    
    % delete repeated words
    [w1u p1 crap] = unique(w1);
    [w2u p2 crap] = unique(w2);
    f1u = f1(:,p1);
    f2u = f2(:,p2);
    
    clear f1 f2 w1 w2;
    if opts.includeRepeated
        w1 = w1r; w2 = w2r; f1 = f1r; f2 = f2r;
    else
        w1 = w1u; w2 = w2u; f1 = f1u; f2 = f2u;
    end
    
    numMatches = min([length(w1) length(w2)]) ;
    %fprintf('RANSAC: %d of the same words appear in each image\n', numMatches); 
    if numMatches < 3
        matches.lol = 'jk';
        score = 0;
        return
    end
    
    % get the 2D coordinates of these features in homogeneous notation
    X1 = f1(1:2,:) ;
    X2 = f2(1:2,:) ;
    X1(3,:) = 1 ;
    X2(3,:) = 1 ;

    thresh = max(max(size)*0.007, 7)*1; 

    % RANSAC
    [u_score best Ha score ok A T] = normal_RANSAC(X1, X2, thresh);
    
    if opts.repeatedScore
        % final score includes scores from repeated structures
        X2_ = Ha * [f1r(1:2,:); ones(1, length(w1r))];
        delta = X2_ - [f2r(1:2,:); ones(1, length(w2r))];
        ok = sum(delta.*delta,1) < thresh^2;
        score = sum(ok);
        f1 = f1r; f2 = f2r; w1 = w1r; w2 = w2r;
    else
        score = u_score;
        ok = ok{best};
    end
    
    matches.A = Ha(1:2,1:2) ;
    matches.T = Ha(1:2,3) ;
    matches.ok = ok ;
    matches.f1 = f1(:, matches.ok) ;
    matches.f2 = f2(:, matches.ok) ;
    matches.words = w1(:, matches.ok);
end
