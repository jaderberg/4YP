clear;

DescPointsPath = 'desc.txt';

% load detected points with corresponding descriptors
FeatData = importdata(DescPointsPath, ' ', 2);
        
% descriptors
Desc = uint8(FeatData.data(:, 7:end))';

% descriptor measurement regions in the format [x; y; theta; a; b; c]
Regions = single(FeatData.data(:, 1:6))';

% plot regions on image
im = imread('oxford_002336.jpg');
imagesc(im);
axis off image ;  hold on ;
for n=1:size(Regions,2)
    % plot each ellipse
    stuff = Regions(:,n); 
    u = stuff(1); v = stuff(2);
    a = stuff(4); b = stuff(5); c = stuff(6); 
    H = [a b; b c];
    H = inv(H);
    vl_plotframe([u v H(1,1) H(1,2) H(2,2)], 'linewidth',0.01);
end
hold off;
