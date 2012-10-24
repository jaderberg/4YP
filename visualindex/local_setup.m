% Distributed precompute
% Max Jaderberg 28/2/12

function [ROOT_DIR IMAGE_DIR NUM_WORDS] = local_setup(n, N)

    % setup vlfeat
    run vlfeat/toolbox/vl_setup ;

    % setup directories
    ROOT_DIR = '/Volumes/4YP/d_rootaffine_turbo+';
    IMAGE_DIR = '/Volumes/4YP/Images/List_of_structures_in_London';
    MONGODB_DIR = fullfile(ROOT_DIR, 'mongodb'); 
    MONGO_LOGS_DIR = fullfile(ROOT_DIR, 'mongo_logs');
    vl_xmkdir(ROOT_DIR);
    vl_xmkdir(MONGODB_DIR);
    vl_xmkdir(MONGO_LOGS_DIR);
    
    % number of visual words in vocab
    NUM_WORDS = 100000;
    
    global g_n;
    global g_N;
    
    g_n = n;
    g_N = N;