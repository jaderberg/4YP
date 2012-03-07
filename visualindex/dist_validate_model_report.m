% Max Jaderberg 5/3/12

function dist_validate_model_report( n_split, N_split, first_host, this_host )

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

% get partial results
files = dir(fullfile(conf.validationResultsDir, '*validation_results.mat')) ;
files = {files(~[files.isdir]).name} ;   
files = sort_nat(files);

validation_results.ground_truth = {};
validation_results.classification_result = [];

for i=1:length(files)
    filepath = fullfile(conf.validationResultsDir, files{i});
    s = load(filepath);
    validation_results.ground_truth = cat(2, validation_results.ground_truth, s.ground_truth);
    validation_results.classification_result = cat(2, validation_results.classification_result, s.classification_result);
end

% get partial class results
files = dir(fullfile(conf.validationResultsDir, '*class_reports.mat')) ;
files = {files(~[files.isdir]).name} ;   
files = sort_nat(files);

class_reports.true_pos = [];
class_reports.false_pos = [];
class_reports.unmatched = [];
class_reports.total = [];

for i=1:length(files)
    filepath = fullfile(conf.validationResultsDir, files{i});
    s = load(filepath);
    class_reports.true_pos = [class_reports.true_pos s.true_pos];
    class_reports.false_pos = [class_reports.false_pos s.false_pos];
    class_reports.unmatched = [class_reports.unmatched s.unmatched];
    class_reports.total = [class_reports.total s.total];
end

save(fullfile(conf.validationResultsDir, 'validation_results-all.mat'), '-STRUCT', 'validation_results');
save(fullfile(conf.validationResultsDir, 'class_repots-all.mat'), '-STRUCT', 'class_reports');

num_images = length(validation_results.ground_truth);
statuses = validation_results.classification_result;
true_pos = length(statuses(statuses==1))*100/num_images;
false_pos = length(statuses(statuses==2))*100/num_images;
unmatched = length(statuses(statuses==0))*100/num_images;

validation_txt = fopen(fullfile(conf.validationResultsDir, 'validation.txt'), 'w');

fprintf(validation_txt, '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n');
fprintf(validation_txt, 'REPORT\n');
fprintf(validation_txt, '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n');
fprintf(validation_txt, 'Num images: %d\n', num_images);
fprintf(validation_txt, 'True positives: %f percent\n', true_pos);
fprintf(validation_txt, 'False positives: %f percent\n', false_pos);
fprintf(validation_txt, 'Unmatched: %f percent\n', unmatched);
fprintf(validation_txt, '\n\n');
fprintf(validation_txt, 'CLASS PERFORMANCE:\n\n');
[s p] = sort(class_reports.true_pos);
for n=3:length(p)
    fprintf(validation_txt, '%f percent true, %f percent false, %f percent unmatched for %s (%d total)\n', class_reports.true_pos(p(n)), class_reports.false_pos(p(n)), class_reports.unmatched(p(n)), folders{p(n)}, class_reports.total(p(n)));
end

fclose(validation_txt);