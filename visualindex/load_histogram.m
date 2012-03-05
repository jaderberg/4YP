% Max Jaderberg 7/1/12

function histogram = load_histogram(image_id, conf, varargin)
    opts.prefix = '';
    opts = vl_argparse(opts, varargin);
    histogram_file = fullfile(conf.histogramsDataDir, [image_id '-' opts.prefix 'histogram.mat']);
    
    if ~exist(histogram_file, 'file')
        histogram = [];
        return
    end
    
    t = load(histogram_file);
    fields = fieldnames(t);
    if isempty(fields);
        histogram = [];
    else
        histogram = t.(fields{1});
    end
    clear t;