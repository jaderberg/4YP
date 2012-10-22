% Max Jaderberg 22/10/12

% Modifies the conf.mat file

old_substr = '~/4YP/data';
new_substr = '/Volumes/4YP/';

conf = load(fullfile('/Volumes/4YP/d_rootaffine_turbo+/', 'conf.mat'));
fields = fieldnames(conf);
for i=1:numel(fields)
    conf.(fields{i}) = strrep(conf.(fields{i}), old_substr, new_substr);
end

save(fullfile(conf.rootDir, 'conf.mat'), '-STRUCT', 'conf');