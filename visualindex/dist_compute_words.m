% Max Jaderberg 3/3/12

function dist_compute_words( n_split, N_split, first_host, this_host )

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

histograms = {} ;
t = 1;
while coll_ims.hasNext()
    image = coll_ims.next();
    image_id = image.get('_id').toString.toCharArray';
    image_name = image.get('name');

    fprintf('Getting words for %s\n', image_name);
    im_descrs = load_descrs(image_id, conf);
    im_words = visualindex_get_words(vocab, im_descrs);
    save(fullfile(conf.wordsDataDir, [image_id '-words.mat']), 'im_words');
    
    clear im_descrs;
    
%     delete the descrs file (its not needed ever again)
    delete(fullfile(conf.descrsDataDir, [image_id '-descrs.mat']))
   
    
    im_histogram = sparse(double(im_words),1,...
                         ones(length(im_words),1), ...
                         vocab.size,1) ;
%     save the raw histogram for later use if needed
    save(fullfile(conf.histogramsDataDir, [image_id '-rawhistogram.mat']), 'im_histogram');
                     
    ids{t} = image_id;
    histograms{t} = im_histogram;   
    t = t + 1;
end
clear im_words image im_histogram image_id;

fprintf('Saving ids and histograms...\n');
save(fullfile(conf.modelDataDir, [int2str(n_split) 'histogramsraw.mat']), 'histograms');
save(fullfile(conf.modelDataDir, [int2str(n_split) 'ids.mat']), 'ids');
fprintf('SAVED!\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');
