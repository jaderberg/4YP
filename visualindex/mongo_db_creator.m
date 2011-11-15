% Max Jaderberg 2011

function [conf, coll] = mongo_db_creator(varargin)
%     Creates the mongodb database with the images.
%   Code from http://stackoverflow.com/questions/3886461/connecting-to-mongodb-from-matlab
%   NB: For mongodb driver reference see http://www.mongodb.org/display/DOCS/Java+Tutorial


    javaaddpath('mongo-2.7.2.jar')

    import com.mongodb.Mongo;
    import com.mongodb.DB;
    import com.mongodb.DBCollection;
    import com.mongodb.BasicDBObject;
    import com.mongodb.DBObject;
    import com.mongodb.DBCursor;
    import org.bson.types.ObjectId;
    
    opts.server = '127.0.0.1'; opts.port = [];
    opts.db = 'imdb'; opts.collection = 'images';
    opts.rootDir = '/Volumes/4YP/visualindex';
    opts = vl_argparse(opts, varargin);

%     Connect to mongodb 
    if isempty(opts.port)
        m = Mongo(opts.server); % connect to local db
    else
        m = Mongo(opts.server, opts.port);
    end
    db = m.getDB(opts.db); % get db object
    colls = db.getCollectionNames(); % get collection names
    coll = db.getCollection(opts.collection); % get DBCollection object


    conf.imageDir = fullfile(opts.rootDir, 'data','oxbuild_images') ;
    conf.gtDir = fullfile(opts.rootDir, 'data', 'oxbuild_gt') ;
    conf.numWords = 50000 ;
   
    conf.dataDir = [conf.imageDir '-index'] ;
    conf.thumbDir = [conf.imageDir] ;
    conf.modelPath = fullfile(conf.dataDir, 'model_mongo.mat') ;
    
%     Get the data files
    if ~exist(conf.gtDir, 'dir')
        fprintf('Downloading and unpacking Oxford building datset gt to %s\n', conf.gtDir) ;
        vl_xmkdir(conf.gtDir) ;
        untar('/Volumes/4YP/visualindex/gt_files_170407.tgz',conf.gtDir) ;
    end
    if ~exist(conf.imageDir, 'dir')
        fprintf('Downloading and unpacking Oxford building datset images to %s\n', conf.imageDir) ;
        vl_xmkdir(conf.imageDir) ;
        untar('/Volumes/4YP/visualindex/oxbuild_images.tgz',conf.imageDir) ;
    end
    
%     Has the database been created?
    files = dir(fullfile(conf.imageDir, '*.jpg')) ;
    files = {files(~[files.isdir]).name} ;
    
    if length(files) <= coll.getCount()
        return
    end
    
%     No database has been created, let's do it

    for i=1:length(files)
%         For each image build a document
%         But first see if it is already in the database
        image_doc = BasicDBObject();
        imageName = char(files(i));
        image_doc.put('name', imageName);
        image_doc.put('directory', conf.imageDir);
        if ~isempty(coll.findOne(image_doc))
%             There is already this image in the collection
            continue
        end
        
        info = imfinfo(fullfile(conf.imageDir, imageName)) ;
        size = BasicDBObject();
        size.put('width', info.Width); size.put('height', info.Height);
        image_doc.put('size', size);
        
        doc(1) = image_doc;
        coll.insert(doc);
    end
    
%     Need to index name?
    coll.createIndex(BasicDBObject('name', 1));
    
%     Ok, now assign a class from the groundtruth files and which set they
%     are in (train/test)
    groundtruth_files = dir(fullfile(conf.gtDir, '*.txt')) ;
    groundtruth_files = {groundtruth_files(~[groundtruth_files.isdir]).name} ;
    
    for i=1:length(groundtruth_files)
        a = regexp(groundtruth_files{i}, '([\w_]+)_[0-9]+_query.txt', 'tokens') ;
        if ~isempty(a)
            cl= a{1} ;
            instances = textread(fullfile(conf.gtDir, groundtruth_files{i}), ...
                               '%s %*f %*f %*f %*f') ;
            for j = 1:length(instances)
                name = char([instances{j}(6:end) '.jpg']);
                im_doc = coll.findOne(BasicDBObject('name', name));
                if isempty(im_doc)
%                     No found image with that name
                    continue
                end
                im_doc.put('set', 'test');
                im_doc.put('class', char(cl));
                coll.save(im_doc);
            end
            
        end
        filename = groundtruth_files{i};
        a = regexp(groundtruth_files{i}, '([\w_]+)_[0-9]+_(good|ok|junk).txt', 'tokens') ;
        if ~isempty(a),
            cl = a{1}{1};
            instances = textread(fullfile(conf.gtDir, groundtruth_files{i}), ...
                               '%s %*f %*f %*f %*f') ;
            for j = 1:length(instances)
                im_doc = coll.findOne(BasicDBObject('name', char([instances{j} '.jpg'])));
                if isempty(im_doc)
%                     No found image with that name
                    continue
                end
                im_doc.put('set', 'train');
                im_doc.put('class', char(cl));
                coll.save(im_doc);
            end
        end
    end
    
%     If needed, you can get the classes by coll.distinct('class');

%     And for reference you can do coll.find(BasicDBObject('class', BasicDBObject('$exists', 0))).count()
    
end