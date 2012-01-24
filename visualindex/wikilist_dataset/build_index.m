% Max Jaderberg 23/11/11

function [histograms ids vocab] = build_index( coll, conf, varargin )
%BUILD_INDEX Builds the index for the dataset images
%   Saves to the mongodb as well as saving in data folder for redundancy.

import com.mongodb.BasicDBObject;
import org.bson.types.ObjectId;

% Setup
opts.numWords = 10000 ;
opts.numKMeansIterations = 20 ;
opts.forceWords = 0; 
opts.skipFeatures = 0;
opts = vl_argparse(opts, varargin) ;

randn('state',0) ;
rand('state',0) ;

vocab.size = opts.numWords ;


% --------------------------------------------------------------------
%                                              Extract visual features
% --------------------------------------------------------------------
% Extract SIFT features from each image.

% read features
coll_ims = coll.find();
num_images = coll_ims.count();
descrs = [];

% Randomly sample the descrs for word creation (rule of thumb
% 30*numWords). If you have around 3000 descrs per image, then to
% select n = 30*numWords descrs at random from all descrs, sample with
% a frequency of n/total_descrs
total_descrs = 3000*num_images;  % approximate
if 30*opts.numWords > total_descrs
    p = 1;
else
    p = 30*opts.numWords/total_descrs;
end
p_ = ceil(1/p);

if opts.skipFeatures && exist(fullfile(conf.modelDataDir, 'sampledescrs.mat'), 'file')
%     Just load the saved sample descrs for word creation
    descrs_struct = load(fullfile(conf.modelDataDir, 'sampledescrs.mat'));
    descrs = descrs_struct.descrs;
    clear descrs_struct;
else
    
    for i = 1:num_images
    %     Retrieve the image database entry
        image = coll_ims.next();
        image_id = image.get('_id').toString.toCharArray';

%         Compute the features
        fprintf('Adding image %s (%d of %d)\n', image.get('name'), i, num_images) ;
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
    end

    save(fullfile(conf.modelDataDir, 'sampledescrs.mat'), 'descrs');
    
end

clear p p_ total_descrs;


% --------------------------------------------------------------------
%                                                  Large scale k-means
% --------------------------------------------------------------------
% Quantize the SIFT features to obtain a visual word vocabulary.
% Implement a fast approximate version of K-means by using KD-Trees
% for quantization.

vocab_file = fullfile(conf.modelDataDir, 'vocab.mat');
if (~exist(vocab_file, 'file')) || opts.forceWords
    fprintf('Creating vocabulary with %d words\n', vocab.size);
    [vocab.centers, vocab.tree] = annkmeans(descrs, vocab.size, 'verbose', true) ;
    save(vocab_file, '-STRUCT', 'vocab');
else
    fprintf('Loading existing vocabulary (%s)\n', vocab_file);
    vocab = load(vocab_file);
end

clear descrs;

% --------------------------------------------------------------------
%                                                           Histograms
% --------------------------------------------------------------------
% Compute a visual word histogram for each image, compute TF-IDF
% weights, and then reweight the histograms.

histograms = cell(1, num_images) ;
coll_ims = coll.find();
for t = 1:num_images
    image = coll_ims.next();
    image_id = image.get('_id').toString.toCharArray';
    image_name = image.get('name');
    if opts.forceWords
        im_words = [];
    else
        im_words = load_words(image_id, conf);
    end
    
    if ~isempty(im_words)
        fprintf('Already got words for %s\n', image_name);
    else
        fprintf('Getting words for %s\n', image_name);
        im_descrs = load_descrs(image_id, conf);
        im_words = visualindex_get_words(vocab, im_descrs);
        save(fullfile(conf.wordsDataDir, [image_id '-words.mat']), 'im_words');
    end
    
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
end
clear im_words image im_histogram image_id;

% compute IDF weights
histograms = cat(2, histograms{:});
vocab.weights = log((size(histograms,2)+1)./(max(sum(histograms > 0,2),eps))) ;
save(vocab_file, '-STRUCT', 'vocab');

% weight and normalize histograms
coll_ims = coll.find();
for t = 1:num_images
    image = coll_ims.next();
    image_id = image.get('_id').toString.toCharArray';
    image_name = image.get('name');
    if opts.forceWords
        im_histogram = [];
    else
        im_histogram = load_histogram(image_id, conf);
    end
    
    if ~isempty(im_histogram)
%         Histogram is already there
        fprintf('Already created histogram for %s\n', image_name);
    else
        fprintf('Creating histogram for %s\n', image_name)
%         apply weightingz
        h = histograms(:,t) .*  vocab.weights ;
        im_histogram = h / max(sum(histograms(:,t)), eps) ;
        clear h;
        save(fullfile(conf.histogramsDataDir, [image_id '-histogram.mat']), 'im_histogram');
    end

    histograms(:,t) = im_histogram;
end

save(fullfile(conf.modelDataDir, 'ids.mat'), 'ids');
save(fullfile(conf.modelDataDir, 'histograms.mat'), 'histograms');

end



