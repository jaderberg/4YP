% Max Jaderberg 3/3/12

function [histograms ids vocab] = dist_compute_features( n_split, N_split, first_host, this_host )
%BUILD_INDEX Builds the index for the dataset images
%   Saves to the mongodb as well as saving in data folder for redundancy.

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

import com.mongodb.BasicDBObject;
import org.bson.types.ObjectId;

% Setup
opts.numWords = num_words ;
opts.numKMeansIterations = 20 ;
opts.forceWords = 0; 
opts.skipFeatures = 0;

randn('state',0) ;
rand('state',0) ;


% --------------------------------------------------------------------
%                                              Extract visual features
% --------------------------------------------------------------------
% Extract SIFT features from each image.


% split images into N parts
total_ims = coll.find().count();
split = floor(total_ims/N_split);
start_image = (n_split-1)*split;
fprintf('Split %d of %d\n', n_split, N_split);
if n_split == N_split
    coll_ims = coll.find().sort(BasicDBObject('name',1)).skip(start_image);
else
    coll_ims = coll.find().sort(BasicDBObject('name',1)).skip(start_image).limit(split);
end

descrs = [];

% Randomly sample the descrs for word creation (rule of thumb
% 30*numWords). If you have around 3000 descrs per image, then to
% select n = 30*numWords descrs at random from all descrs, sample with
% a frequency of n/total_descrs
total_descrs = 2000*total_ims;  % approximate
sample_rate = 20*opts.numWords;
if sample_rate > total_descrs
    p = 1;
else
    p = sample_rate/total_descrs;
end
p_ = ceil(1/p);

i = 1;
while coll_ims.hasNext()
%     Retrieve the image database entry
    image = coll_ims.next();
    image_id = image.get('_id').toString.toCharArray';

%         Compute the features
    fprintf('Adding image %s (%d of %d)\n', image.get('name'), i, split) ;
    im = imread(image.get('path')) ;
    [im_frames,im_descrs] = visualindex_get_features(im) ;

%         Add to filesystem
    save(fullfile(conf.framesDataDir, [image_id '-frames.mat']), 'im_frames');
    save(fullfile(conf.descrsDataDir, [image_id '-descrs.mat']), 'im_descrs');

    clear im_frames image;

%     Randomly sample for word creation
    r = randi([1 p_], size(im_descrs, 2), 1);
    sample_descrs = im_descrs(:, r==p_);
    if ~isempty(sample_descrs)
        if isempty(descrs)
            descrs = sample_descrs;
        else
            descrs = [descrs sample_descrs];
        end
    end

    clear r sample_descrs im_descrs;
    i = i + 1;
end

save(fullfile(conf.modelDataDir, [int2str(n_split) 'sampledescrs.mat']), 'descrs');
fprintf('Saved sample descrs\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');





