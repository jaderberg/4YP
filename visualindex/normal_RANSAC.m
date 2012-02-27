% Normal RANSAC (it's damn slow though)
% Max Jaderberg 21/2/12

function [u_score Ha ok_best] = normal_RANSAC(f1, f2, thresh)

    X1 = f1(1:2,:) ;
    X2 = f2(1:2,:) ;
    X1(3,:) = 1 ;
    X2(3,:) = 1 ;

    % RANSAC
    randn('state',0) ;
    rand('state',0) ;
    numRansacIterations = 500 ;
    for t = 1:numRansacIterations
        % select a subset of 3 matched features at random
        subset = vl_colsubset(1:length(X1(1,:)), 3) ;

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
    
    [u_score, best] = max(score) ;

    % now compute best tranformation from all inliers
    try
        Ha = vgg_Haffine_from_x_MLE(X1(:,ok{best}), X2(:,ok{best}));
    catch
        Ha = [A{best} T{best}; 0 0 1];
    end

    ok_best = ok{best};