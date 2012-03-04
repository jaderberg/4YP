% Max Jaderberg 3/3/12

function dist_compute_histograms( n_split, N_split, first_host, this_host )
    
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
vocab_file = fullfile(conf.modelDataDir, 'vocab.mat');
vocab = load(vocab_file);

import com.mongodb.BasicDBObject;

% split images into N parts
total_ims = coll.find().count();
split = ceil(total_ims/N_split);
start_image = (n_split-1)*split;
fprintf('Split %d of %d\n', n_split, N_split);
if n_split == N_split
    coll_ims = coll.find().sort(BasicDBObject('name',1)).skip(start_image);
else
    coll_ims = coll.find().sort(BasicDBObject('name',1)).skip(start_image).limit(split);
end

histograms = [];

% weights + normalize histograms
t = 1;
while coll_ims.hasNext()
    image = coll_ims.next();
    image_id = image.get('_id').toString.toCharArray';
    
    fprintf('Creating histogram for %s\n', image_id)
    % load raw histogram
    s = load(fullfile(conf.histogramsDataDir, [image_id '-rawhistogram.mat']));
    raw_h = s.im_histogram;
    clear s;
    % apply weightingz
    h = raw_h .*  vocab.weights ;
    im_histogram = h / max(sum(raw_h), eps) ;
    clear h;
    save(fullfile(conf.histogramsDataDir, [image_id '-histogram.mat']), 'im_histogram');

    histograms(:,t) = im_histogram;
    
    t = t + 1;
end

save(fullfile(conf.modelDataDir, [int2str(n_split) 'histograms.mat']), 'histograms');
fprintf('Saved histograms\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');
