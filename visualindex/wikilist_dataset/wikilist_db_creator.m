% Max Jaderberg 7/1/12

function [conf, class_names, coll] = wikilist_db_creator(root_dir, image_dir, varargin)
% This creates the database + filestructure for the wiki list dataset
%   Remeber to run mongodb! /usr/local/Cellar/mongodb/2.0.1-x86_64/bin/mongod --dbpath /Volumes/4YP/wikilist_visualindex/mongo_db/
%   Code from http://stackoverflow.com/questions/3886461/connecting-to-mongodb-from-matlab
%   NB: For mongodb driver reference see http://www.mongodb.org/display/DOCS/Java+Tutorial


%     javaaddpath('mongo-2.7.2.jar')

    import com.mongodb.Mongo;
    import com.mongodb.DB;
    import com.mongodb.DBCollection;
    import com.mongodb.BasicDBObject;
    import com.mongodb.DBObject;
    import com.mongodb.DBCursor;
    import org.bson.types.ObjectId;
    
    opts.server = '127.0.0.1'; opts.port = [];
    opts.db = 'imdb'; opts.collection = 'images';
    opts = vl_argparse(opts, varargin);


%     Connect to mongodb 
    fprintf('Connecting to mongodb...\n');
    if isempty(opts.port)
        m = Mongo(opts.server); % connect to local db
    else
        m = Mongo(opts.server, opts.port);
    end
    db = m.getDB(opts.db); % get db object
    coll = db.getCollection(opts.collection); % get DBCollection object
    

    fprintf('Creating image database...\n');
    
%   Create data dirs
    conf.rootDir = root_dir;
    conf.imageDir = image_dir;
    conf.dataDir = fullfile(root_dir, 'data');
    vl_xmkdir(conf.dataDir);
   
    conf.modelDataDir = fullfile(conf.dataDir, 'model');
    conf.framesDataDir = fullfile(conf.dataDir, 'frames');
    conf.descrsDataDir = fullfile(conf.dataDir, 'descriptors');
    conf.histogramsDataDir = fullfile(conf.dataDir, 'histograms');
    conf.wordsDataDir = fullfile(conf.dataDir, 'words');
    conf.superhistsDataDir = fullfile(conf.dataDir, 'superhists');
    conf.classhistsDataDir = fullfile(conf.dataDir, 'classhists');
    conf.classesDataDir = fullfile(conf.dataDir, 'classes');
    vl_xmkdir(conf.modelDataDir); 
    vl_xmkdir(conf.framesDataDir);
    vl_xmkdir(conf.descrsDataDir);
    vl_xmkdir(conf.histogramsDataDir);
    vl_xmkdir(conf.wordsDataDir);
    vl_xmkdir(conf.superhistsDataDir);
    vl_xmkdir(conf.classhistsDataDir);
    vl_xmkdir(conf.classesDataDir);
    
%     Get the file names
    files = dir(fullfile(conf.imageDir, '*.jpg')) ;
    files = {files(~[files.isdir]).name} ;   
    files = sort(files); % sort alphabetically
    n_images = length(files);
    fprintf('Found %d jpgs\n', n_images);
    
    classes = {};
    failed = 0;
    for i=1:n_images
        fprintf('Adding image %d of %d...\n', i, n_images);
        filename = files{i};
        
%         Get image info
        try
            info = imfinfo(fullfile(conf.imageDir, filename)) ;
        catch exc
            fprintf('Could not process image %s - skipping\n', filename);
            failed = failed + 1;
            continue
        end
        
%         For each image build a document
%         But first see if it is already in the database
        image_doc = BasicDBObject();
        image_doc.put('name', filename);
        image_doc.put('path', fullfile(conf.imageDir, filename));
        if ~isempty(coll.findOne(image_doc))
%             There is already this image in the collection
            fprintf('Image already added.\n');
            continue
        end
        
%         extract class name from filename
        a = regexp(filename, '([^|]*+)|', 'tokens');
        if isempty(a)
            fprintf('Invalid file name for db (%s)\n', filename);
        end
        image_class = char(a{1});
        if isempty(classes)
            classes{1} = image_class;
        else
            if ~strcmp(classes{end}, image_class)
                classes{end+1} = image_class;
            end
        end

        image_doc.put('class', image_class);
        size = BasicDBObject();
        size.put('width', info.Width); size.put('height', info.Height);
        image_doc.put('size', size);
        
        doc(1) = image_doc;
        coll.insert(doc);

    end
    clear filename image_class a;
    
    fprintf('%d added, %d failed to add\n', n_images - failed, failed);
    
% %     Create an index on 'name' for fast querying
%     coll.createIndex(BasicDBObject('name', 1));
    
    class_names = classes;
    clear classes;
    save(fullfile(conf.modelDataDir, 'class_names.mat'), 'class_names');
    fprintf('Found %d classes\n', length(model.classes.class_names));