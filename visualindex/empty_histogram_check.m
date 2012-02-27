% Max Jaderberg 8/1/12

%  Q: How many useful histograms have no entries (ie are not spatially
%  similar to any other image in that class)

s = load('/Volumes/4YP/wikilist_visualindex/data/model/useful_histograms.mat');
useful_histograms = s.useful_histograms;
clear s;

N = size(useful_histograms, 2);
n_empty = 0;
for i=1:N
    if sum(useful_histograms(:,i)) == 0
        n_empty = n_empty + 1;
    end
end

fprintf('%d out of %d (%f percent) are empty\n', n_empty, N, n_empty*100/N);