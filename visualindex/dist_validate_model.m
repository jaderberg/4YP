% Max Jaderberg 5/3/12

function dist_validate_model( n_split, N_split, first_host, this_host )

[root_dir image_dir num_words] = dist_setup(n_split, N_split);

%     load config file
try
    conf = load(fullfile(root_dir, 'conf.mat'));
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

%     get mongodb collection
[m db coll] = mongo_get_collection('server',first_host);

validation_results_dir = fullfile(conf.rootDir, 'validation_results');
vl_xmkdir(validation_results_dir);
true_pos_dir = fullfile(validation_results_dir, 'true_positives');
vl_xmkdir(true_pos_dir);
false_pos_dir = fullfile(validation_results_dir, 'false_positives');
vl_xmkdir(false_pos_dir);
unmatched_dir = fullfile(validation_results_dir, 'unmatched');
vl_xmkdir(unmatched_dir);

conf.validationDir = fullfile(conf.rootDir, 'validation_images');


% find all the folders in that directory
folders = dir(fullfile(conf.validationDir, '*')) ;
folders = {folders([folders.isdir]).name} ; 
folders = folders(3:end);

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

n_image = 1;
for n=1:length(folders)
    class_name = folders{n};
    num_true = 0; num_false = 0; num_unmatched = 0; num_total = 0;
    class_dir = fullfile(conf.validationDir, class_name);
    files = dir(fullfile(class_dir, '*.jpg')) ;
    files = [files; dir(fullfile(class_dir, '*.jpeg'))];
    files = {files(~[files.isdir]).name} ;   
    for i=1:length(files)
        % run a query with the image
        image = files{i};
        args.display = 1; args.image_path = fullfile(class_dir, image);
        res = dist_get_objects(args, coll);
        validation_results.ground_truth{n_image} = class_name;
        if ~isempty(res.classes)
            validation_results.model_classification{n_image} = res.classes{1};
            if strcmp(res.classes{1}, class_name)
                validation_results.classification_result(n_image) = 1; % true positive
                num_true = num_true + 1;
                % save the figure with the matches
                save_figure(1, fullfile(true_pos_dir, [strrep(image,'.','') '|' class_name '|' res.classes{1}]));
            else
                validation_results.classification_result(n_image) = 2; % false positive
                num_false = num_false + 1;
                save_figure(1, fullfile(false_pos_dir, [strrep(image,'.','') '|' class_name '|' res.classes{1}]));
            end
        else
            validation_results.model_classification{n_image} = 'NA';
            validation_results.classification_result(n_image) = 0; % no match
            num_unmatched = num_unmatched + 1;
            save_figure(1, fullfile(unmatched_dir, [strrep(image,'.','') '|' class_name '|unmatched']));
        end 
        n_image = n_image + 1;
        num_total = num_total + 1;
    end
    class_reports.true_pos(n) = num_true*100/num_total;
    class_reports.false_pos(n) = num_false*100/num_total;
    class_reports.unmatched(n) = num_unmatched*100/num_total;
    class_reports.total(n) = num_total;
end

fprintf('Saving results...\n');
save(fullfile(validation_results_dir, [int2str(n_split) 'validation_results.mat']), 'validation_results');
save(fullfile(validation_results_dir, [int2str(n_split) 'class_reports.mat']), 'class_reports');

m.close();

fprintf('All done!\n');

% save file to signal good ending
a = 1;
save(fullfile('finished_flags',[int2str(n_split) '-' mfilename '-finished.mat']), 'a');
