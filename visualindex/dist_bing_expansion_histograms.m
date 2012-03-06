% Max Jaderberg 4/3/12

function dist_bing_expansion_histograms( n_split, N_split, first_host, this_host )

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

%     get mongodb collection
[m db coll] = mongo_get_collection('server',first_host);

% get vocab
vocab_file = fullfile(conf.modelDataDir, 'vocab-bing.mat');
vocab = load(vocab_file);

% get ids
s = load(fullfile(conf.modelDataDir, 'ids-bing-all.mat'));
ids = s.ids;

% split ids up
split = ceil(length(ids)/N_split);
start_id = (n_split-1)*split + 1;
end_id = start_id + split - 1;
fprintf('Split %d of %d\n', n_split, N_split);
if n_split == N_split
    ids = ids(start_id:end);
else
    ids = ids(start_id:end_id);
end

histograms = [];

% weights + normalize histograms
for t=1:length(ids)
    image_id = ids{t};
    
    fprintf('Creating histogram for %s\n', image_id)
    % load raw histogram
    s = load(fullfile(conf.histogramsDataDir, [image_id '-bingaugmentedrawhistogram.mat']));
    raw_h = s.im_histogram;
    clear s;
    % apply weightingz
    h = raw_h .*  vocab.weights ;
    im_histogram = h / max(sum(raw_h), eps) ;
    im_histogram = sparse(im_histogram);
    clear h;
    save(fullfile(conf.histogramsDataDir, [image_id '-bingaugmentedhistogram.mat']), 'im_histogram');

    histograms(:,t) = im_histogram;
    
end

histograms = sparse(histograms);

save(fullfile(conf.modelDataDir, [int2str(n_split) 'histograms-bing.mat']), 'histograms');
fprintf('Saved histograms\n');

fprintf('BING EXPANSION COMPLETE\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');
