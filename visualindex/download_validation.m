% Download validation set from Google images

% library must be imported by running javaaddpath('mongo-2.7.2.jar')

%--------------------------------------------------------------------------
% SET THIS TO THE ROOT_DIR USED IN preprocess_solution.m
    ROOT_DIR = '/Volumes/4YP/bing_expansion';
%=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;

%     load config file
try
    conf = load(fullfile(ROOT_DIR, 'conf.mat'));
    try
        conf = conf.conf;
    catch
        conf = conf;
    end
catch err
    fprintf('ERROR: could not find conf.mat. Make sure preprocess_solution.m has been run.\n');
    result = 0;
    return
end

%     load mongo collection
coll = mongo_get_collection();

conf.validationDir = fullfile(conf.rootDir, 'validation_images');
vl_xmkdir(conf.validationDir);

m = load(fullfile(conf.modelDataDir, 'class_names.mat'));
class_names = m.class_names;
clear m;

for n=1:length(class_names)
    try
        class_name = class_names{n};
        class_dir = fullfile(conf.validationDir, class_name);
        vl_xmkdir(class_dir);
        fprintf('Downloading validation images for %s...\n', class_name);
        search_term = class_name;
        search_term = strrep(search_term, ' ', '%20');
        search_term = strrep(search_term, '_', '%20');

        request_url = ['https://ajax.googleapis.com/ajax/services/search/images?v=1.0' ...
            '&q=-en.wikipedia.org ' search_term ...
            '&as_filetype=jpg' ...
            '&imgsz=xxlarge' ...
            '&imgtype=photo' ...
            '&rsz=8' ...
        ];

        response = urlread(request_url);

        resp = parse_json(response);

        results = resp{1}.responseData.results;
        n_images = length(results);
        for i=1:length(results)
            fprintf('   > %d of %d downloading...\n', i, n_images);
            photo_url = results{i}.url;
            try
                im = imreadurl(photo_url,30000);
            catch err
                try
                    im = imread(photo_url,60000);
                catch err
                    fprintf('   ...ERROR: TIMEOUT\n');
                    continue
                end
            end
    %             resize if too big
            [maxRes maxDim] = max(size(im));
            maxSize = 1000;
            if maxRes > maxSize;
                scale_factor = maxSize/maxRes;
                im = imresize(im, scale_factor);
            end
            imwrite(im, fullfile(class_dir, [results{i}.imageId '.jpg']));
        end
    catch
        continue
    end
end

save(fullfile(ROOT_DIR, 'conf.mat'), 'conf');