% Max Jaderberg 7/1/12

function preprocess_solution()
% This is the preprocessing that needs to be done before a solution goes
% live

%--------------------------------------------------------------------------
% SETUP THESE VARIABLES
%--------------------------------------------------------------------------
    ROOT_DIR = '/Volumes/4YP/wikilist_visualindex';
    IMAGE_DIR = '/Volumes/4YP/Images/List_of_structures_in_London';
%-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

%     setup VLFeat
    run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;
    
%     setup db
    [conf, model, coll] = wikilist_db_creator(ROOT_DIR, IMAGE_DIR);
    
%     build the index

%     supercharge images