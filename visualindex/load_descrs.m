% Max Jaderberg 7/1/12

function descrs = load_descrs(image_id, conf, varargin)
    opts.prefix = '';
    opts = vl_argparse(opts, varargin);
    descrs_file = fullfile(conf.descrsDataDir, [image_id '-' opts.prefix 'descrs.mat']);
    
    if ~exist(descrs_file, 'file')
        descrs = [];
        return
    end
    
    t = load(descrs_file);
    fields = fieldnames(t);
    if isempty(fields);
        descrs = [];
    else
        descrs = t.(fields{1});
    end
    clear t;