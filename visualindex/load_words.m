% Max Jaderberg 7/1/12

function words = load_words(image_id, conf, varargin)
    opts.prefix = '';
    opts = vl_argparse(opts, varargin);
    word_file = fullfile(conf.wordsDataDir, [image_id '-' opts.prefix 'words.mat']);
    
    if ~exist(word_file, 'file')
        words = [];
        return
    end
    
    t = load(word_file);
    fields = fieldnames(t);
    if isempty(fields);
        words = [];
    else
        words = t.(fields{1});
    end
    clear t;