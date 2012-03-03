% Max Jaderberg 3/3/12

function dist_vocab_creation( n_split, N_split, first_host, this_host )

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

fprintf('Gettings descrs...\n');

% get sampled descrs
files = dir(fullfile(conf.modelDataDir, '*sampledescrs.mat')) ;
files = {files(~[files.isdir]).name} ;   

fprintf('Found %d descr fragments\n', length(files));

descrs = [];

for i=1:length(files)
    filepath = fullfile(conf.modelDataDir, files{i});
    s = load(filepath);
    descrs = [descrs s.descrs];
end

fprintf('Saving concatenated descrs...\n');
save(fullfile(conf.modelDataDir, 'sampledescrs-all.mat'), 'descrs');

clear s;

vocab.size = num_words;

vocab_file = fullfile(conf.modelDataDir, 'vocab.mat');
fprintf('Creating vocabulary with %d words\n', vocab.size);
[vocab.centers, vocab.tree] = annkmeans(descrs, vocab.size, 'verbose', true, 'parallel', false) ;
save(vocab_file, '-STRUCT', 'vocab');
fprintf('Vocab created and saved!\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');
