% Max Jaderberg 8/1/12

function coll = mongo_get_collection(varargin)

    import com.mongodb.Mongo;
    import com.mongodb.DB;
    import com.mongodb.DBCollection;

    opts.server = '127.0.0.1'; opts.port = [];
    opts.db = 'imdb'; opts.collection = 'images';
    opts = vl_argparse(opts, varargin);


%     Connect to mongodb 
    fprintf('Connecting to mongodb...');
    if isempty(opts.port)
        m = Mongo(opts.server); % connect to local db
    else
        m = Mongo(opts.server, opts.port);
    end
    db = m.getDB(opts.db); % get db object
    coll = db.getCollection(opts.collection); % get DBCollection object
    fprintf('got %s collection\n', opts.collection);