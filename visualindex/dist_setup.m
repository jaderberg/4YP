% Distributed precompute
% Max Jaderberg 28/2/12

function [ROOT_DIR IMAGE_DIR] = dist_setup()

    % setup vlfeat
    run vlfeat/toolbox/vl_setup ;

    % setup directories
    ROOT_DIR = '~/4YP/data/bing_expansion';
    IMAGE_DIR = '~/4YP/data/List_of_structures_in_London';
    MONGODB_DIR = fullfile(ROOT_DIR, 'mongodb'); 
    vl_xmkdir(ROOT_DIR);
    vl_xmkdir(MONGODB_DIR);
    
    % start mongodb in forked process
    system(['~/4YP/mongodb/bin/mongod --dbpath ' MONGODB_DIR ' &']);
    
    % number of visual words in vocab
    NUM_WORDS = 100000;
    
    