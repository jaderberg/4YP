function [f,d] = visualindex_get_features(im)
% VISUALINDEX_GET_FEATURES  Extract features from an image
%   [F,D] = VISUALINDEX_GET_FEATURES(MODEL, IM) extracts the SIFT
%   frames F and descriptors D from image IM for indexing based on the
%   specified MODEL.

% Auhtor: Andrea Vedaldi

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
