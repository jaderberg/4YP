% Max Jaderberg 16/1/12

function [conf] = flickr_expansion(classes, conf, varargin)
%     Expands on the images from Wikipedia using publicly available Flickr
%     images. For Flickr api reference see http://www.flickr.com/services/api/flickr.photos.search.html
%     Requires the xml_toolbox http://www.mathworks.com/matlabcentral/fileexchange/4278
    
    addpath('xml_toolbox');
    
    opts.maxResolution = 0;
    opts = vl_argparse(opts, varargin);

    api_key = '96b5267887dfe14499dedb947f8f8f72';
    api_secret = 'cf86ec38be5e3925';
    
    conf.flickrDir = fullfile(conf.rootDir, 'flickr_images');
    vl_xmkdir(conf.flickrDir);
    
    for n=1:length(classes)
%         Download images first...
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
                '&per_page=20'...
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

        for i=1:n_photos
            photo_struct = photos{i}.ATTRIBUTE;
            fprintf('-> %s (%d of %d)\n', photo_struct.title, i, n_photos);
            filename = [class_name '|' photo_struct.id '.jpg'];
%             check if photo exists
            if exist(fullfile(class_dir, filename), 'file')
                fprintf('   ...file already exists!\n');
                continue
            end
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
    %         resize if too big
            if opts.maxResolution
                [maxRes maxDim] = max(size(im));
                if maxRes > opts.maxResolution
                    scale_factor = opts.maxResolution/maxRes;
                    im = imresize(im, scale_factor);
                end
            end
    %         save to flickrDir
            fprintf('   ...saved as %s!\n', filename);
            imwrite(im, fullfile(class_dir, filename));
        end
    end
    
%     Next pick out corresponding ones etc etc