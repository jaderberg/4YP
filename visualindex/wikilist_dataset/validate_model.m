% Validate model
% NB: ps -e|grep -v TTY|awk {'print "echo -n \"Process: "$4"\tPID: "$1"\tNumber of FH: \"; lsof -p "$1"|wc -l"'} > out; . ./out

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

conf.validationDir = fullfile(conf.rootDir, 'validation_images');

% find all the folders in that directory

folders = dir(fullfile(conf.validationDir, '*')) ;
folders = {folders([folders.isdir]).name} ; 

n_image = 1;
for n=3:length(folders)
    class_name = folders{n};
    class_dir = fullfile(conf.validationDir, class_name);
    files = dir(fullfile(class_dir, '*.jpg')) ;
    files = [files; dir(fullfile(class_dir, '*.jpeg'))];
    files = {files(~[files.isdir]).name} ;   
    for i=1:length(files)
        % run a query with the image
        image = files{i};
        args.display = 0; args.image_path = fullfile(class_dir, image);
        res = demo_wiki_get_objects(args);
        validation_results.ground_truth{n_image} = class_name;
        if ~isempty(res.classes)
            validation_results.model_classification{n_image} = res.classes{1};
            if strcmp(res.classes{1}, class_name)
                validation_results.classification_result(n_image) = 1; % true positive
            else
                validation_results.classification_result(n_image) = 2; % false positive
            end
        else
            validation_results.model_classification{n_image} = 'NA';
            validation_results.classification_result(n_image) = 0; % no match
        end 
        n_image = n_image + 1;
    end
    save(fullfile(conf.rootDir, 'validation_results.mat'), 'validation_results');
    fclose('all');
end

num_images = length(validation_results.ground_truth);
statuses = validation_results.classification_result;
true_pos = length(statuses(statuses==1))*100/num_images;
false_pos = length(statuses(statuses==2))*100/num_images;
unmatched = length(statuses(statuses==0))*100/num_images;

validation_txt = fopen(fullfile(conf.rootDir, 'validation.txt'), 'w');

fprintf(validation_txt, '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n');
fprintf(validation_txt, 'REPORT\n');
fprintf(validation_txt, '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n');
fprintf(validation_txt, 'Num images: %d\n', num_images);
fprintf(validation_txt, 'True positives: %f percent\n', true_pos);
fprintf(validation_txt, 'False positives: %f percent\n', false_pos);
fprintf(validation_txt, 'Unmatched: %f percent\n', unmatched);

fclose(validation_txt);