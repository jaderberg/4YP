% Max Jaderberg 7/1/12

function frames = load_frames(image_id, conf, varargin)
    opts.prefix = '';
    opts = vl_argparse(opts, varargin);
    frames_file = fullfile(conf.framesDataDir, [image_id '-' opts.prefix 'frames.mat']);
    
    if ~exist(frames_file, 'file')
        frames = [];
        return
    end
    
    t = load(frames_file);
    fields = fieldnames(t);
    if isempty(fields);
        frames = [];
    else
        frames = t.(fields{1});
    end
    clear t;