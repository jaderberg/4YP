% Distributed precompute
% Max Jaderberg 28/2/12

function [ROOT_DIR IMAGE_DIR] = dist_setup(n, N)

    % setup vlfeat
    run vlfeat/toolbox/vl_setup ;

    % setup directories
    ROOT_DIR = '~/4YP/data/bing_expansion';
    IMAGE_DIR = '~/4YP/data/List_of_structures_in_London';
    MONGODB_DIR = fullfile(ROOT_DIR, 'mongodb'); 
    MONGO_LOGS_DIR = fullfile(ROOT_DIR, 'mongo_logs');
    vl_xmkdir(ROOT_DIR);
    vl_xmkdir(MONGODB_DIR);
    vl_xmkdir(MONGO_LOGS_DIR);
    
    % start mongodb in forked process
    fprintf('Deleting mongo logs...\n');
    system(['rm -f ' MONGO_LOGS_DIR '/*']);
    fprintf('Running mongodb...\n');
    system(['~/4YP/mongodb/bin/mongod --dbpath ' MONGODB_DIR ' > ' MONGO_LOGS_DIR '/mongo' int2str(n) '.txt &']);
    pause(10); % pause to allow mongod to boot up
    fprintf('Mongodb running!\n');
    
    % number of visual words in vocab
    NUM_WORDS = 100000;