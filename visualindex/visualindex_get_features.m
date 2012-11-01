function [f,d] = visualindex_get_features(im,varargin)
% VISUALINDEX_GET_FEATURES  Extract features from an image
%   [F,D] = VISUALINDEX_GET_FEATURES(MODEL, IM) extracts the SIFT
%   frames F and descriptors D from image IM for indexing based on the
%   specified MODEL.

% Auhtor: Andrea Vedaldi

opts.affine = true;
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



if opts.colour
    % add in RGB, LAB, HSV to add 9 extra dimensions
    if size(im, 3) == 1
        % not rgb
        d = [d; zeros(9, size(f, 2))];
        return
    end
    im_rgb = uint32(im);
    I_rgb{1} = vl_imintegral(im_rgb(:,:,1));
    I_rgb{2} = vl_imintegral(im_rgb(:,:,2));
    I_rgb{3} = vl_imintegral(im_rgb(:,:,3));
    im_hsv = rgb2hsv(im);
    I_hsv{1} = vl_imintegral(im_hsv(:,:,1));
    I_hsv{2} = vl_imintegral(im_hsv(:,:,2));
    I_hsv{3} = vl_imintegral(im_hsv(:,:,3));
    im_lab = vl_xyz2lab(vl_rgb2xyz(im));
    I_lab{1} = vl_imintegral(im_lab(:,:,1));
    I_lab{2} = vl_imintegral(im_lab(:,:,2));
    I_lab{3} = vl_imintegral(im_lab(:,:,3));
    width = 1; % window of averaging pixels
    extra_d = zeros(9, size(f, 2));
    for i=1:size(f, 2)
        frame = f(:,i);
        if opts.affine
            C = [frame(4) frame(5); frame(5) frame(6)];
            C_area = abs(real(prod(sqrt(eig(C)))*pi)) ; % see comments of http://www.mathworks.com/matlabcentral/fileexchange/4705
            scale = 19.6*C_area; % empirical scaling factor to get it inline with normal sift scales
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
        rows = t:b;
        cols = l:r;
        mean_rgb = (1/255)*[integral_average(I_rgb{1}, rows, cols); integral_average(I_rgb{2}, rows, cols); integral_average(I_rgb{3}, rows, cols)];
        mean_lab = [0.01*integral_average(I_lab{1}, rows, cols); (1/256)*(integral_average(I_lab{2}, rows, cols) + 128); (1/256)*(integral_average(I_lab{3}, rows, cols) + 128)];
        mean_hsv = abs([integral_average(I_hsv{1}, rows, cols); integral_average(I_hsv{2}, rows, cols); integral_average(I_hsv{3}, rows, cols)]);

        extra_d(:,i) = [mean_rgb; mean_lab; mean_hsv];
    end
    d = [d; extra_d];
end

if opts.root
    for i=1:size(d,2)
        d_i = d(:,i);
        d(:,i) = sqrt(d_i/sum(d_i));
    end
end

function avg = integral_average(i_im, rows, cols)
% http://computersciencesource.wordpress.com/2010/09/03/computer-vision-the-integral-image/
    area = double(length(rows)*length(cols));
    D = i_im(rows(end),cols(end));
    if rows(1) == 1 && cols(1) == 1
        avg = double(D)/area;
        return
    elseif rows(1) == 1
        A = 0; B = 0;
        C = i_im(rows(end),cols(1)-1);
    elseif cols(1) == 1
        A = 0; C = 0;
        B = i_im(rows(1)-1,cols(end));
    else
        A = i_im(rows(1)-1,cols(1)-1);
        B = i_im(rows(1)-1,cols(end));
        C = i_im(rows(end),cols(1)-1);
    end 
    avg = double(A + D - B - C)/area;
