% Max Jaderberg 7/1/12

function preprocess_solution()
% This is the preprocessing that needs to be done before a solution goes
% live

%==========================================================================
% THINGS THAT NEED TO BE DONE
%--------------------------------------------------------------------------
% 1. Setup these variables
%--------------------------------------------------------------------------
    ROOT_DIR = '/Volumes/4YP/bing_expansion';
    IMAGE_DIR = '/Volumes/4YP/Images/List_of_structures_in_London';
    NUM_WORDS = 100000;
%--------------------------------------------------------------------------    
% 2. Create ROOT_DIR and ROOT_DIR/mongo_db
%--------------------------------------------------------------------------
% 3. Run:
%    /usr/local/Cellar/mongodb/2.0.1-x86_64/bin/mongod --dbpath ROOT_DIR/mongo_db/
%--------------------------------------------------------------------------
% 4. Make sure the mongodb java library is imported. 
%    In Matlab shell run javaaddpath('mongo-2.7.2.jar')
%-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

%     setup VLFeat
    run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;
    
%     setup db
    [conf, class_names, coll] = wikilist_db_creator(ROOT_DIR, IMAGE_DIR, 'copyImages', 1, 'maxResolution', 1000);
        
%     build the index
    [histograms ids vocab] = build_index(coll, conf, 'numWords', NUM_WORDS);
        
    
%     Flickr expansion
    [conf vocab_f histograms_f ids_f] = flickr_expansion(class_names,conf,coll,vocab);
    
%     supercharge images
    %[super_class_histograms classes_useful_hists] = supercharge_images(class_names, coll, conf, vocab);