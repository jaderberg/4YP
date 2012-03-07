% Max Jaderberg 4/3/12

function dist_bing_expansion_weights( n_split, N_split, first_host, this_host )

[root_dir image_dir num_words] = dist_setup(n_split, N_split);

%     load config file
try
    conf = load(fullfile(root_dir, 'conf.mat'));
    try
        conf = conf.conf;
    catch
        conf = conf;
    end
catch err
    fprintf('ERROR: could not find conf.mat. Make sure preprocess_solution.m has been run.\n');
    result = 0;
    return
end

% get raw histograms
files = dir(fullfile(conf.modelDataDir, '*histograms-raw-bing.mat')) ;
files = {files(~[files.isdir]).name} ;
files = sort_nat(files);

histograms = [];

for i=1:length(files)
    filepath = fullfile(conf.modelDataDir, files{i});
    s = load(filepath);
    histograms = cat(2, histograms, s.histograms{:});
end

% get ids
files = dir(fullfile(conf.modelDataDir, '*ids-bing.mat')) ;
files = {files(~[files.isdir]).name} ;   
files = sort_nat(files);

ids = {};
for i=1:length(files)
    filepath = fullfile(conf.modelDataDir, files{i});
    s = load(filepath);
    ids = cat(2, ids, s.ids);
end
clear s;

fprintf('Saving full ids...\n');
save(fullfile(conf.modelDataDir, 'ids-bing-all.mat'), 'ids');

fprintf('Saving full rawhistograms...\n');
save(fullfile(conf.modelDataDir, 'histograms-raw-bing-all.mat'), 'histograms');

vocab_file = fullfile(conf.modelDataDir, 'vocab.mat');
vocab = load(vocab_file);

% compute IDF weights
fprintf('Computing IDF weights...\n');
vocab.weights = log((size(histograms,2)+1)./(max(sum(histograms > 0,2),eps))) ;
save(fullfile(conf.modelDataDir, 'vocab-bing.mat'), '-STRUCT', 'vocab');
fprintf('Vocab file saved\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');