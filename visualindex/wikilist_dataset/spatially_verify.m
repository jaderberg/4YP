% Max Jaderberg 28/12/11

function [score, matches] = spatially_verify(f1,w1,f2,w2,size)
    % The geometric verfication is a simple RANSAC affine matcher. It can
    % be significantly improved.

    % find the features that are mapped to the same visual words
    [d1, m1] = ismember(w1, w2);
    [d2, m2] = ismember(w2, w1);
    f1 = f1(:,d1==1);
    w1 = w1(d1==1);
    m1 = m1(d1~=0);
    f2 = f2(:,d2==1);
    w2 = w2(d2==1);
    m2 = m2(d2~=0);
    
        
    numMatches = min([length(w1) length(w2)]) ;
    %fprintf('RANSAC: %d of the same words appear in each image\n', numMatches); 
    if numMatches < 3
        matches.lol = 'jk';
        score = 0;
        return
    end
    
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
        for k=1:nn2
            for l=1:nn1
                f1sub(:,k*l) = f1(:,i-1+l);
                f2sub(:,k*l) = f2(:,i-1+k);
            end
        end
        w1 = [w1(1:i-1) wsub w1(i+nn1:end)];
        w2 = [w2(1:i-1) wsub w2(i+nn2:end)];
        f1 = [f1(:,1:i-1) f1sub f1(:,i+nn1:end)];
        f2 = [f2(:,1:i-1) f2sub f2(:,i+nn2:end)];
        clear f1sub f2sub;
        
        i = i + length(wsub);        
    end
    
    % get the 2D coordinates of these features in homogeneous notation
    X1 = f1(1:2,:) ;
    X2 = f2(1:2,:) ;
    X1(3,:) = 1 ;
    X2(3,:) = 1 ;

    thresh = max(max(size)*0.02, 10)*1; 

    % RANSAC
    randn('state',0) ;
    rand('state',0) ;
    numRansacIterations = 500 ;
    for t = 1:numRansacIterations
      % select a subset of 3 matched features at random
      subset = vl_colsubset(1:length(w1), 3) ;
      
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
    % now compute transformation based on ALL inliers from best
    warning off all % lots of singular warnings in optimization    
    % initialize at best guess so far    
    AT = [A{best} T{best}];
    % optimize geometric error
    AT = fminsearch(@geometric_error, AT, optimset('Display', 'off', 'TolFun', 1e-8, 'TolX', 1e-8), X1(:,ok{best}), X2(:,ok{best}));
    warning on all

    matches.A = AT(:,1:2) ;
    matches.T = AT(:,3) ;
    matches.ok = ok{best} ;
    matches.f1 = f1(:, matches.ok) ;
    matches.f2 = f2(:, matches.ok) ;
    matches.words = w1(:, matches.ok);
end

% optimization cost function
function cost = geometric_error(AT, X1, X2)
    % the geometric error of the current transformation
    F = [AT; 0 0 1];
    X2_ = F * X1;
    X1_ = F \ X2;
    cost = sum(sum((X2_-X2).^2).^2) + sum(sum((X1_-X1).^2).^2);
end