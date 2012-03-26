function [f,d] = visualindex_get_features(im,varargin)
% VISUALINDEX_GET_FEATURES  Extract features from an image
%   [F,D] = VISUALINDEX_GET_FEATURES(MODEL, IM) extracts the SIFT
%   frames F and descriptors D from image IM for indexing based on the
%   specified MODEL.

% Auhtor: Andrea Vedaldi

opts.affine = true;
opts = vl_argparse(opts,varargin);


if ~opts.affine
    %area = size(im,1) * size(im,2) ;
    %firstOctave = max(ceil(.5 * log2(area / 1024^2)), -1) ;
    firstOctave = -1;
    normThresh = 0.1;
    peakThresh = 0.025;
    try
        [f,d] = vl_sift(im2single(rgb2gray(im)), ...
                        'firstoctave', firstOctave,  ...
                        'normthresh', normThresh, ...
                        'peakthresh', peakThresh, ...
                        'floatdescriptors') ;
    catch err
    %     probably a grayscale image
        [f,d] = vl_sift(im2single(im), ...
                        'firstoctave', firstOctave,  ...
                        'normthresh', normThresh, ...
                        'peakthresh', peakThresh, ...
                        'floatdescriptors') ;
    end

    % remove the low gradient ones
    s = find(all(d==0)) ;
    f(:,s) = [] ;
    d(:,s) = [] ;
else
    %--=-=--==---
    % TODO: Need to explore -sift vs -gloh (extended sift) 
    %--=-=--==---
    % get hessian-affine features
    imwrite(im, 'temp.jpg');
    system('affine_detector/linux_bin2/detect_points -i temp.jpg -hesaff -o det.txt > det_log.txt');
    system('affine_detector/linux_bin2/compute_descriptors -i temp.jpg -p1 det.txt -sift -o3 desc.txt -scale-mult 1.732 > desc_log.txt');
    % load detected points with corresponding descriptors
    featData = importdata('desc.txt', ' ', 2);    
    % descriptors
    d = single(featData.data(:, 7:end))';
    % descriptor measurement regions in the format [x; y; theta; a; b; c]
    f = double(featData.data(:, 1:6))';
    system('rm -f desc.txt det.txt desc_log.txt det_log.txt temp.jpg');
end
