% Max Jaderberg 7/1/12

function frames = load_frames(image_id, conf)
    frames_file = fullfile(conf.framesDataDir, [image_id '-frames.mat']);
    
    if ~exist(frames_file, 'file')
        frames = [];
        return
    end
    
    t = load(frames_file);
    frames = t.im_frames;
    clear t;