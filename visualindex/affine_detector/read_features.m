clear;

DescPointsPath = 'desc.txt';

% load detected points with corresponding descriptors
FeatData = importdata(DescPointsPath, ' ', 2);
        
% descriptors
Desc = uint8(FeatData.data(:, 7:end))';

% descriptor measurement regions in the format [x; y; theta; a; b; c]
Regions = single(FeatData.data(:, 1:6))';