function v = visualindex_get_histogram(vocab, words)
% VISUALINDEX_GET_HISTOGRAM  Get visual word histogram
%   V = VISUALINDEX_GET_HISTOGRAM(MODEL, WORDS) returns the histogram
%   of visual words V given the visual words WORDS.

% Author: Andrea Vedaldi

v = sparse(double(words),1,...
           ones(length(words),1), ...
           vocab.size,1) ;
v = v .*  vocab.weights ;
v = v / norm(v) ;
