% Max Jaderberg 7/1/12

function frames = load_frames(image_id, conf)
    frames_file = fullfile(conf.framesDataDir, [image_id '-augmentedframes.mat']);
    
    if ~exist(frames_file, 'file')
        frames = [];
        return
    end
    
    t = load(frames_file);
    frames = t.c_frames;
    clear t;