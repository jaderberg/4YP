% Distributed precompute
% Max Jaderberg 28/2/12

function [ROOT_DIR IMAGE_DIR NUM_WORDS] = dist_setup(n, N)

    % setup vlfeat
    run vlfeat/toolbox/vl_setup ;

    % setup directories
    ROOT_DIR = '~/4YP/data/album11_ransac_turbo';
    IMAGE_DIR = '~/4YP/data/ukno1albums_wiki';
    MONGODB_DIR = fullfile(ROOT_DIR, 'mongodb'); 
    MONGO_LOGS_DIR = fullfile(ROOT_DIR, 'mongo_logs');
    vl_xmkdir(ROOT_DIR);
    vl_xmkdir(MONGODB_DIR);
    vl_xmkdir(MONGO_LOGS_DIR);
    
    % number of visual words in vocab
    NUM_WORDS = 100000;