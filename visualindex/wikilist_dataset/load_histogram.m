% Max Jaderberg 7/1/12

function histogram = load_histogram(image_id, conf)
    histogram_file = fullfile(conf.histogramsDataDir, [image_id '-augmentedhistogram.mat']);
    
    if ~exist(histogram_file, 'file')
        histogram = [];
        return
    end
    
    t = load(histogram_file);
    histogram = t.c_histogram;
    clear t;