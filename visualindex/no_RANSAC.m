% noRANSAC
% Max Jaderberg 27/2/12

function [score H ok] = no_RANSAC(f1, f2, thresh)

    X1 = f1(1:2,:) ;
    X2 = f2(1:2,:) ;
    X1(3,:) = 1 ;
    X2(3,:) = 1 ;
    
    n_correspondences = length(X1(1,:));
    
    % for each correspondence
    for i=1:n_correspondences
        % compute transformation (s 0 tx; 0 s ty; 0 0 1) where s = s2/s1
        s = f2(3,i)/f1(3,i);
        T = f2(1:2,i) - s*f1(1:2,i);
        H{i} = [s 0 T(1); 0 s T(2); 0 0 1]; 
        % score all the other points from transformation
        X2_ = H{i} * X1;
        delta = X2_ - X2;
        ok_rough{i} = sum(delta.*delta,1) < (1*thresh)^2;
        score_rough(i) = sum(ok_rough{i});
    end
    
    % for the best basic transformation, compute full affine with all the
    % inliers
    [top_rough_score, top_rough_i] = max(score_rough);
    
    try
        H = vgg_Haffine_from_x_MLE(X1(:,ok_rough{top_rough_i}), X2(:,ok_rough{top_rough_i}));
    catch
        H = H{i};
    end
    
    % get score from new transformation
    X2_ = H * X1;
    delta = X2_ - X2;
    ok = sum(delta.*delta,1) < thresh^2;
    score = sum(ok);