% Max Jaderberg 16/1/12

function [conf] = flickr_expansion(classes, conf, coll, vocab, varargin)
%     Expands on the images from Wikipedia using publicly available Flickr
%     images. For Flickr api reference see http://www.flickr.com/services/api/flickr.photos.search.html
%     Requires the xml_toolbox http://www.mathworks.com/matlabcentral/fileexchange/4278
    import com.mongodb.BasicDBObject;

    addpath('xml_toolbox');
    
    opts.maxResolution = 0;
    opts.nPhotos = '20';
    opts.matchThresh = 15;
    opts = vl_argparse(opts, varargin);

    api_key = '96b5267887dfe14499dedb947f8f8f72';
    api_secret = 'cf86ec38be5e3925';
    
    conf.flickrDir = fullfile(conf.rootDir, 'flickr_images');
    vl_xmkdir(conf.flickrDir);
    
    for n=1:length(classes)
%-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-         
%         Download images first...
%-=-=-=-=-=-=-==-=-=-=-=-=-=-=-=-=-=-=-=-=
        class_name = classes{n};
        class_dir = fullfile(conf.flickrDir, class_name);
        vl_xmkdir(class_dir);
        fprintf('Expanding images for class %s...\n', class_name);
        search_term = class_name;
        search_term = strrep(search_term, ' ', '+');
        search_term = strrep(search_term, '_', '+');

        cmd = ['method=flickr.photos.search'...
                '&format=rest'...
                '&api_key=' api_key ...
                '&text=' search_term ...
                '&sort=relevance'...
                '&per_page=' opts.nPhotos...
                '&privacy_filter=1'...
                '&content_type=1&media=photos']; %photos only 
        fprintf('Searching Flickr for %s...\n', search_term);
        response = urlread(['http://api.flickr.com/services/rest/?' cmd]);
        resp_struct = xml_parseany(response);

    %     download url:
    %       http://farm{num}.static.flickr.com/{server}/{id}_{secret}_b.jpg
        photos = resp_struct.photos{1}.photo;
        n_photos = length(photos);

        fprintf('Downloading %d photos to %s...\n', n_photos, conf.imageDir);
        
        f_filenames = {};
        f_words = {};
        f_frames = {};
        for i=1:n_photos
            photo_struct = photos{i}.ATTRIBUTE;
            fprintf('-> %s (%d of %d)\n', photo_struct.title, i, n_photos);
            filename = [class_name '|' photo_struct.id '.jpg'];
%             check if photo exists
            if exist(fullfile(class_dir, filename), 'file')
                fprintf('   ...file already exists!\n');
                im = imread(fullfile(class_dir, filename));
            else          
    %             grab it from flickr
                photo_url = ['http://farm' photo_struct.farm '.static.flickr.com/' photo_struct.server '/' photo_struct.id '_' photo_struct.secret '_b.jpg'];
                try
                    im = imread(photo_url);
                catch err
                    try
                        photo_url = strrep(photo_url, ['farm' photo_struct.farm '.'], '');
                        im = imread(photo_url);
                    catch err
                        continue
                    end
                end
    %             resize if too big
                if opts.maxResolution
                    [maxRes maxDim] = max(size(im));
                    if maxRes > opts.maxResolution
                        scale_factor = opts.maxResolution/maxRes;
                        im = imresize(im, scale_factor);
                    end
                end
    %             save to flickrDir
                fprintf('   ...saved as %s!\n', filename);
                imwrite(im, fullfile(class_dir, filename));
            end
%             get features + words
            [frames, descrs] = visualindex_get_features(im);
            words = visualindex_get_words(vocab, descrs);
            f_filenames{i} = filename;
            f_words{i} = words;
            f_frames{i} = frames;
            clear im words frames descrs;
        end
        
%-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=         
%         Now do the combining with the existing images
%-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        fprintf('Augmenting Flickr image words for %s...\n', class_name);
%         get images of this class
        class_ims = coll.find(BasicDBObject('class', class_name));
        for i=1:class_ims.count()
            class_im = class_ims.next();
            fprintf('-> %s (%d of %d)\n', class_im.get('name'), i, class_ims.count());
            c_id = class_im.get('_id').toString.toCharArray';
            c_frames = load_frames(c_id, conf);
            c_words = load_words(c_id, conf);
            c_im = imread(class_im.get('path'));
            
            extra_words = [];
%             for each flickr image for this class try and pull in some
%             words if it is spatially verified
            for j=1:length(f_filenames) 
                if isempty(f_filenames{j})
                    continue
                end
                [score matches] = spatially_verify(c_frames,c_words,f_frames{j},f_words{j},size(c_im), 'includeRepeated', 0);
                                    fprintf('--> %s from Flickr is similar (score: %d) - adding words\n', f_filenames{j}, score);

                if score > opts.matchThresh
                    f_im = imread(fullfile(class_dir, f_filenames{j}));
                    figure(1)
                    visualindex_plot_matches(matches, c_im, f_im) ;
%                     rectangle of matched words on flickr image
                    f_xmin = min(matches.f2(1,:)); f_ymin = min(matches.f2(2,:));
                    f_xmax = max(matches.f2(1,:)); f_ymax = max(matches.f2(2,:));
                    figure(2); title('Flickr image');
                    imshow(f_im); hold on;
                    X_rect = [f_xmin f_xmax f_xmax f_xmin; f_xmax f_xmax f_xmin f_xmin];
                    Y_rect = [f_ymax f_ymax f_ymin f_ymin; f_ymax f_ymin f_ymin f_ymax];
                    line(X_rect, Y_rect, 'color', 'r', 'marker', '.'); hold off;
%                     transform rectangle onto wiki image
                    rect_coords_top = [X_rect(1,:); Y_rect(1,:); 1 1 1 1];
                    rect_coords_bottom = [X_rect(2,:); Y_rect(2,:); 1 1 1 1];
                    transformation = inv([matches.A matches.T; 0 0 1]);
                    rect_coords_top = transformation*rect_coords_top;
                    rect_coords_bottom = transformation*rect_coords_bottom;
                    X_rect = [rect_coords_top(1,:); rect_coords_bottom(1,:)];
                    Y_rect = [rect_coords_top(2,:); rect_coords_bottom(2,:)];
                    figure(3); title('Wiki image');
                    imshow(c_im); hold on;
                    line(X_rect, Y_rect, 'color', 'r', 'marker', '.'); hold off;
                    pause()
                end
            end
        end
    end