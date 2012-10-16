imshow(c_im);
hold on;
scatter(c_frames(1,:), c_frames(2,:), 'blue', 'filled')
imshow(f_im);
hold on;
scatter(f_frames{j}(1,:), f_frames{j}(2,:), 'green', 'filled')
visualindex_plot_matches(matches, c_im, f_im) ;

imshow(f_im); hold on;
x = f_xmin - 10;
y = f_ymin - 10;
w = f_xmax-f_xmin+20;
h = f_ymax-f_ymin+20;
rect = [x y w h];
rectangle('Position', rect, 'EdgeColor', 'r');
scatter(extra_frames_f(1,:), extra_frames_f(2,:), 'green', 'filled')

imshow(c_im);
hold on;
scatter(c_frames(1,:), c_frames(2,:), 'blue', 'filled')
scatter(extra_frames_c(1,:), extra_frames_c(2,:), 'green', 'filled')
