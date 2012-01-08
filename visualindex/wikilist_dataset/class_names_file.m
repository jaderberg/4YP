% Max Jaderberg 8/1/12

% Prints the classes to a text file for reference

s = load('/Volumes/4YP/wikilist_visualindex/data/model/class_names.mat');
class_names = s.class_names;
clear s;


file = fopen('/Volumes/4YP/wikilist_visualindex/data/class_names.txt', 'w');
for i=1:length(class_names)
    fprintf(file, '%s\n', class_names{i});
end
fclose(file);