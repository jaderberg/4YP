% Max Jaderberg 7/1/12

function descrs = load_descrs(image_id, conf)
    descrs_file = fullfile(conf.descrsDataDir, [image_id '-descrs.mat']);
    
    if ~exist(descrs_file, 'file')
        descrs = [];
        return
    end
    
    t = load(descrs_file);
    descrs = t.im_descrs;
    clear t;