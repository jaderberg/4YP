function [f,d] = visualindex_get_features(im,varargin)
% VISUALINDEX_GET_FEATURES  Extract features from an image
%   [F,D] = VISUALINDEX_GET_FEATURES(MODEL, IM) extracts the SIFT
%   frames F and descriptors D from image IM for indexing based on the
%   specified MODEL.

% Auhtor: Andrea Vedaldi

opts.affine = false;
opts.root = true;
opts.colour = true;
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
        if opts.colour
            d = single(zeros(137,0));
        else
            d = single(zeros(128,0));
        end
        f = double(zeros(4,0));
    end
    system(['rm -f ' desc ' ' det ' ' desc_log ' ' det_log ' ' temp_im]);
end

if opts.root
    for i=1:size(d,2)
        d_i = d(:,i);
        d(:,i) = sqrt(d_i/sum(d_i));
    end
end

if opts.colour
    % add in RGB, LAB, HSV to add 9 extra dimensions
    size(im)
    size(d)
    size(f)
    if size(im, 3) == 1
        % not rgb
        d = [d; zeros(9, size(f, 2))];
        return
    end
    im_hsv = rgb2hsv(im);
    im_lab = vl_xyz2lab(vl_rgb2xyz(im));
    width = 2; % window of averaging pixels
    extra_d = zeros(9, size(f, 2));
    for i=1:size(f, 2)
        frame = f(:,i);
        if opts.affine
            scale = mean([frame(4) frame(6)]);
        else
            scale = frame(3);
        end
        w = ceil(width*scale);
        x = round(frame(1)); y = round(frame(2));
        l = x - w; 
        r = x + w;
        t = y - w;
        b = y + w;
        if l < 1;
            l = 1;
        end
        if r > size(im, 2)
            r = size(im, 2);
        end
        if t < 1
            t = 1;
        end
        if b > size(im, 1);
            b = size(im, 1);
        end
        sub_rgb = im(t:b,l:r,:);
        sub_lab = im_lab(t:b,l:r,:);
        sub_hsv = im_hsv(t:b,l:r,:);
        mean_rgb = squeeze(mean(mean(sub_rgb)));
        mean_lab = squeeze(mean(mean(sub_lab)));
        mean_hsv = squeeze(mean(mean(sub_hsv)));
        extra_d(:,i) = [mean_rgb; mean_lab; mean_hsv];
    end
    d = [d; extra_d];
end
