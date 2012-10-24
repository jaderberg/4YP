% MSER playaround

im = imread('/Volumes/4YP/d_rootaffine_turbo+/images/Duke_of_York_Column/1755|Duke_of_York_Column.jpg');
I = uint8(rgb2gray(im)) ;
[r,f] = vl_mser(I,'MinDiversity',0.7,...
                'MaxVariation',0.2,...
                'Delta',10) ;
figure(1); clf
imagesc(im); axis image off ; drawnow ; hold on;
f = vl_ertr(f) ;
vl_plotframe(f) ; hold off;

M = zeros(size(I)) ;
for x=r'
 s = vl_erfill(I,x) ;
 M(s) = M(s) + 1;
end

figure(2) ;
clf ; imagesc(I) ; hold on ; axis equal off; colormap gray ;
[c,h]=contour(M,(0:max(M(:)))+.5) ;
set(h,'color','y','linewidth',3) ;
