% Max Jaderberg 5/3/12

function dist_validate_model_report( n_split, N_split, first_host, this_host )

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

% get partial results
files = dir(fullfile(conf.modelDataDir, '*validation_results.mat')) ;
files = {files(~[files.isdir]).name} ;   
files = sort(files);

validation_results.ground_truth = {};
validation_results.classification_result = [];

for i=1:length(files)
    filepath = fullfile(conf.modelDataDir, files{i});
    s = load(filepath);
    validation_results.ground_truth = cat(2, validation_results.ground_truth, s.ground_truth);
    validation_results.classification_result = cat(2, validation_results.classification_result, s.classification_result);
end

% get partial class results
files = dir(fullfile(conf.modelDataDir, '*class_reports.mat')) ;
files = {files(~[files.isdir]).name} ;   
files = sort(files);

