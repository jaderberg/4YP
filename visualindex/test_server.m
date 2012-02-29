% test script for lolz
function test_server(n, N, first_host, this_host)
a = n;
b = N;
c = a*100/b;
pause(10);
save(['test_server' int2str(n) '.mat'], 'c');
fprintf('Matlab test ran successfully on %s (%d of %d)\n',this_host,n,N);
quit();