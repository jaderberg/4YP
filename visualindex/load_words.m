% Max Jaderberg 7/1/12

function words = load_words(image_id, conf)
    word_file = fullfile(conf.wordsDataDir, [image_id '-augmentedwords.mat']);
    
    if ~exist(word_file, 'file')
        words = [];
        return
    end
    
    t = load(word_file);
    words = t.c_words;
    clear t;