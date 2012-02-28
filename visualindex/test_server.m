% test script for lolz
function test_server(n, N)
a = n;
b = N;
c = a*100/b;
pause(10000);
save(['test_server' int2str(n) '.mat'], 'c');
fprintf('Matlab test ran successfully (%d of %d)\n',n,N);
quit();