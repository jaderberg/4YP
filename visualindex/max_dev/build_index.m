% Max Jaderberg 23/11/11

function [ output_args ] = build_index( coll, conf )
%BUILD_INDEX Builds the index for the dataset images
%   Saves to the mongodb as well as saving in data folder for redundancy.


% Create file structure for saving the index
conf.modelDataDir = [conf.dataDir '/model'];
conf.framesDataDir = [conf.dataDir '/frames'];
conf.descrsDataDir = [conf.dataDir '/descrs'];
conf.histogramsDataDir = [conf.dataDir '/histograms'];
vl_xmkdir(conf.modelDataDir); 
vl_xmkdir(conf.framesDataDir);
vl_xmkdir(conf.descrsDataDir);
vl_xmkdir(conf.histogramsDataDir);

% Setup
opts.numWords = 10000 ;
opts.numKMeansIterations = 20 ;
opts = vl_argparse(opts, varargin) ;

randn('state',0) ;
rand('state',0) ;

model.rerankDepth = 40 ;
vocab.size = opts.numWords ;


% --------------------------------------------------------------------
%                                              Extract visual features
% --------------------------------------------------------------------
% Extract SIFT features from each image.

% read features
num_images = coll.find().count();
descrs = cell(1,num_images) ;

% Randomly sample the descrs for word creation (rule of thumb
% 30*numWords). If you have around 3000 descrs per image, then to
% select n = 30*numWords descrs at random from all descrs, sample with
% a frequency of n/total_descrs
total_descrs = 3000*num_images;  % approximate
if 30*numWords > total_descrs
    p = 1;
else
    p = ceil(30*numWords/total_descrs);
end

for i = 1:num_images
%     Retrieve the image database entry
    image = coll.find().skip(i-1).limit(1).toArray.get(0);
    image_id = image.get('_id').toString.toCharArray';
    im_frames = mongo_get_frames(coll, 'id', image_id);
    im_descrs = mongo_get_descrs(coll, 'id', image_id);
    
    if (~isempty(im_frames)) && (~isempty(im_descrs))
%         The sift features are already computed
       fprintf('Already added image %s (%d of %d)\n', image.get('name'), i, num_images) ;
       continue 
    end
    
%     Compute the features
    fprintf('Adding image %s (%d of %d)\n', image.get('name'), i, num_images) ;
    
    image_name = image.get('name');
    
    im = imread(fullfile(image.get('directory'), image_name)) ;
    [im_frames,im_descrs] = visualindex_get_features(model, im) ;
    
%     Add to mongoDB
    im_model = BasicDBObject();
    im_model.put('frames', serialize(im_frames,3));
    im_model.put('descrs', serialize(im_descrs,3));
    image.put('model', im_model);
    coll.save(image);
    
%     Add to filesystem
    save(fullfile(conf.framesDataDir, [image_name '-frames.mat']), 'im_frames');
    save(fullfile(conf.descrsDataDir, [image_name '-descrs.mat']), 'im_descrs');
    
    clear im_frames image im_model;
    
%     Randomly sample for word creation
    r = randi([1 1/p], size(im_descrs, 2), 1);
    sample_descrs = im_descrs(r==p);
    descrs = [descrs sample_descrs];
    
    clear r sample_descrs im_descrs;
end



end

