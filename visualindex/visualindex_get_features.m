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
    global g_n;
    if isempty(g_n)
        file_num = randi(99999999);
    else
        file_num = g_n;
    end
    % get hessian-affine features
    temp_im = sprintf('temp%d.jpg', file_num);
    det = sprintf('det%d.txt', file_num);
    det_log = sprintf('det_log%d.txt', file_num);
    desc = sprintf('desc%d.txt', file_num);
    desc_log = sprintf('desc_log%d.txt', file_num);
    imwrite(im, temp_im);
    system(['affine_detector/linux_bin2/detect_points -i ' temp_im ' -hesaff -o ' det ' > ' det_log]);
    system(['affine_detector/linux_bin2/compute_descriptors -i ' temp_im ' -p1 ' det ' -sift -o3 ' desc ' -scale-mult 1.732 > ' desc_log]);
    % load detected points with corresponding descriptors
    try
        featData = importdata(desc, ' ', 2);
        % descriptors
        d = single(featData.data(:, 7:end))';
        % descriptor measurement regions in the format [x; y; theta; a; b; c]
        f = double(featData.data(:, 1:6))';
    catch exc
        fprintf('Error computing features\n');
        d = single(zeros(128,0));
        f = double(zeros(4,0));
    end
    system(['rm -f ' desc ' ' det ' ' desc_log ' ' det_log ' ' temp_im]);
end
