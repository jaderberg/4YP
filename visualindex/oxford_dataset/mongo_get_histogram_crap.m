% Max Jaderberg 24/11/11

function histogram = mongo_get_histogram_crap( collection, vocab_size, varargin )
%MONGO_GET_FRAME returns the histogram object for the id
%   input either 'id', id (the mongoDB id as char) or 'dir', dir, 'name', name. If not found an
%   empty vector is returned. Assumes vl_setup has been run. You can only
%   get the histogram from the words

    opts.id = []; opts.dir = []; opts.name = [];
    opts = vl_argparse(opts, varargin);
    
    words = [];

    if ~isempty(opts.id)
        words = mongo_get_words(collection, 'id', opts.id);
    end
    
    if ~isempty(opts.dir) && ~isempty(opts.name)
        words = mongo_get_words(collection, 'dir', opts.dir, 'name', opts.name);
    end

    
    if ~isempty(words)
        histogram = sparse(double(words),1,...
                             ones(length(words),1), ...
                             vocab_size,1) ;
    else
        histogram = [];
    end
    
    

end


