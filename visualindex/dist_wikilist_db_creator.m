% Max Jaderberg 28/2/12

function [conf, class_names, coll] = dist_wikilist_db_creator(n_split, N_split, first_host, this_host)
% This creates the database + filestructure for the wiki list dataset
% distributed over N machines (assuming N << length(folders))

    [root_dir image_dir num_words] = dist_setup(n_split, N_split);

    opts.copyImages = 1;
    opts.maxResolution = 1000;

    import com.mongodb.Mongo;
    import com.mongodb.DB;
    import com.mongodb.DBCollection;
    import com.mongodb.BasicDBObject;
    import com.mongodb.DBObject;
    import com.mongodb.DBCursor;
    import org.bson.types.ObjectId;
    
%     get mongodb collection
    [m db coll] = mongo_get_collection('server',first_host);
    
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
    folders_raw = dir(fullfile(image_dir, '*')) ;
    folders_raw = {folders_raw([folders_raw.isdir]).name} ; 
    i = 1;
    for n=3:length(folders_raw)
        folders{i} = folders_raw{n};
        i = i + 1;
    end
    clear folders_raw;
    class_names = folders;
    
    % split folders into N parts
    split = ceil(length(folders)/N_split);
    start_folder = (n_split-1)*split + 1;
    end_folder = start_folder + split - 1;
    fprintf('Split %d of %d\n', n_split, N_split);
    if n_split == N_split
        folders = folders(start_folder:end);
    else
        folders = folders(start_folder:end_folder);
    end
    
    failed = 0;
    n_image = 1;
    for n=1:length(folders)
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
                new_filepath = fullfile(conf.imageDir, class_name, filename);
                imwrite(im, new_filepath);
                clear im
                % getting info of copied file
                info = imfinfo(new_filepath) ;
                file_path = new_filepath;
            end
            
            image_doc.put('path', file_path);

            image_doc.put('class', class_name);
            size_db = BasicDBObject();
            size_db.put('width', info.Width); size_db.put('height', info.Height);
            image_doc.put('size', size_db);

            doc(1) = image_doc;
            coll.insert(doc);
            n_image = n_image + 1;
        end
    end
    
    
    fprintf('%d added, %d failed to add\n', n_image - failed, failed);
    
    % save classes (ie folder names)
    save(fullfile(conf.modelDataDir, 'class_names.mat'), 'class_names');
    
    fprintf('Found %d classes\n', length(class_names));
    save(fullfile(conf.rootDir, 'conf.mat'), '-STRUCT', 'conf');
    
    % save file to signal good ending
    a = 1;
    save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');
    