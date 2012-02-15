% Max Jaderberg 7/1/12

function histogram = load_histogram(image_id, conf)
    histogram_file = fullfile(conf.histogramsDataDir, [image_id '-histogram.mat']);
    
    if ~exist(histogram_file, 'file')
        histogram = [];
        return
    end
    
    t = load(histogram_file);
    histogram = t.im_histogram;
    clear t;