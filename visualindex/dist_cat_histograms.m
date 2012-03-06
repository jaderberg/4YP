% Max Jaderberg 4/3/12

function dist_cat_histograms( n_split, N_split, first_host, this_host )

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

% get histograms
files = dir(fullfile(conf.modelDataDir, '*histograms.mat')) ;
files = {files(~[files.isdir]).name} ; 
files = sort(files);

histograms = [];

for i=1:length(files)
    filepath = fullfile(conf.modelDataDir, files{i});
    s = load(filepath);
    histograms = sparse(cat(2, histograms, s.histograms));
end

% save histograms
save(fullfile(conf.modelDataDir, 'histograms-all.mat'), 'histograms');
fprintf('Saved all histograms!\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');