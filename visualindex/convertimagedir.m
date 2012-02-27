% Convert image download filesystem from flat to directory structure
% images should be named <class_name>|<filename>.jpg

function convertimagedir(current_dir, destination_dir)

run /Users/jaderberg/Sites/4YP/visualindex/vlfeat/toolbox/vl_setup ;

if ~exist(current_dir, 'dir')
    error('Supplied image directory does not exist.');
end

vl_xmkdir(destination_dir);

% get images
files = dir(fullfile(current_dir, '*.jpg')) ;
files = {files(~[files.isdir]).name} ;   
files = sort(files); % sort alphabetically
n_images = length(files);
    
fprintf('Found %d jpgs\n', n_images);

for i=1:n_images
    try
        filename = files{i};
        file_path = fullfile(current_dir, filename); 

        % extract class name
        a = regexp(filename, '([^|]*+)|', 'tokens');
        if isempty(a)
            fprintf('Invalid file name for db (%s)\n', filename);
        end
        image_class = char(a{1});
        class_dir = fullfile(destination_dir, image_class);
        vl_xmkdir(class_dir);
        im = imread(file_path);
        imwrite(im, fullfile(class_dir, filename));
        clear im;
    catch
        continue
    end
end

fprintf('Conversion done! See %s\n', destination_dir);