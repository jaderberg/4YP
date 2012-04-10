function resultsgraph()

close all;

% Graph
x = [0 5 10 15 25 35 50];
y = [22.6 25.2 26.1 27.8 31.1 31.2 31.7];

scatter(x,y,'filled'); hold on;
plot(x,y,'Color', 'red')
xlabel('# turbo images downloaded');
ylabel('% yield');

% % regression
% function error = negexp(t)
%     y_est = t(1) - t(2)*exp(-t(3)*x);
%     error = sum((y_est-y).^2);
% end
% 
% t = fminsearch(@negexp,[max(y) max(y)-min(y) 1],optimset('MaxFunEvals',99999,'MaxIter',9999));
% 
% x_fit = min(x):0.1:max(x);
% y_fit = t(1) - t(2)*exp(-t(3)*x_fit);
% 
% plot(x_fit,y_fit); hold off;

end

