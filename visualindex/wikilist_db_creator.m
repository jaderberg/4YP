% Max Jaderberg 7/1/12

function [conf, class_names, coll] = wikilist_db_creator(root_dir, image_dir, varargin)
% This creates the database + filestructure for the wiki list dataset
%   Remeber to run mongodb! /usr/local/Cellar/mongodb/2.0.1-x86_64/bin/mongod --dbpath /Volumes/4YP/wikilist_visualindex/mongo_db/
%   Code from http://stackoverflow.com/questions/3886461/connecting-to-mongodb-from-matlab
%   NB: For mongodb driver reference see http://www.mongodb.org/display/DOCS/Java+Tutorial


%     javaaddpath('mongo-2.7.2.jar')

    opts.copyImages = 0;
    opts.maxResolution = 0;
    opts = vl_argparse(opts, varargin);

    import com.mongodb.Mongo;
    import com.mongodb.DB;
    import com.mongodb.DBCollection;
    import com.mongodb.BasicDBObject;
    import com.mongodb.DBObject;
    import com.mongodb.DBCursor;
    import org.bson.types.ObjectId;
    
%     get mongodb collection
    [m db coll] = mongo_get_collection();
    
    fprintf('Creating image database...\n');
    
%   Create data dirs
    conf.rootDir = root_dir;
    if opts.copyImages || opts.maxResolution
        conf.imageDir = fullfile(root_dir, 'images');
        vl_xmkdir(conf.imageDir);
    else
        conf.imageDir = image_dir;
    end
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
    
    % get class folders in dir
    folders = dir(fullfile(image_dir, '*')) ;
    folders = {folders([folders.isdir]).name} ; 

    classes = {};
    failed = 0;
    
    n_image = 1;
    for n=3:length(folders)
        class_name = folders{n};
        class_dir = fullfile(image_dir, class_name);
        fprintf('Adding images from class %s...', class_name);
        
        % get image files
        files = dir(fullfile(class_dir, '*.jpg')) ;
        files = [files; dir(fullfile(class_dir, '*.jpeg'))];
        files = {files(~[files.isdir]).name} ;   
        n_images = length(files);
        fprintf('found %d images\n', n_images);
        for i=1:n_images
            filename = files{i};
        	file_path = fullfile(class_dir, filename);
            % Get image info
            try
                info = imfinfo(file_path) ;
            catch exc
                fprintf('Could not process image %s - skipping\n', filename);
                failed = failed + 1;
                continue
            end

            % For each image build a document
            % But first see if it is already in the database
            image_doc = BasicDBObject();
            image_doc.put('name', filename);
            image_doc.put('path', fullfile(conf.imageDir, filename));
            if ~isempty(coll.findOne(image_doc))
                % There is already this image in the collection
                fprintf('Image already added.\n');
                continue
            end

            % copy image to new working directory and resize if required
            if opts.copyImages || opts.maxResolution
                im = imread(file_path);
                if opts.maxResolution
                    [maxRes maxDim] = max(size(im));
                    if maxRes > opts.maxResolution
                        scale_factor = opts.maxResolution/maxRes;
                        im = imresize(im, scale_factor);
                    end
                end
                vl_xmkdir(fullfile(conf.imageDir, class_name));
                imwrite(im, fullfile(conf.imageDir, class_name, filename));
                clear im
                % getting info of copied file
                info = imfinfo(fullfile(conf.imageDir, filename)) ;
            end

            if isempty(classes)
                classes{1} = class_name;
            else
                if ~strcmp(classes{end}, class_name)
                    classes{end+1} = class_name;
                end
            end

            image_doc.put('class', class_name);
            size_db = BasicDBObject();
            size_db.put('width', info.Width); size_db.put('height', info.Height);
            image_doc.put('size', size_db);

            doc(1) = image_doc;
            coll.insert(doc);
        end
        n_image = n_image + 1;
    end
    
    
    fprintf('%d added, %d failed to add\n', n_images - failed, failed);
    
% %     Create an index on 'name' for fast querying
%     coll.createIndex(BasicDBObject('name', 1));
    
    class_names = classes;
    clear classes;
    if isempty(class_names)
        t = load(fullfile(conf.modelDataDir, 'class_names.mat'));
        class_names = t.class_names;
    else
        save(fullfile(conf.modelDataDir, 'class_names.mat'), 'class_names');
    end
    fprintf('Found %d classes\n', length(class_names));
    save(fullfile(conf.rootDir, 'conf.mat'), '-STRUCT', 'conf');