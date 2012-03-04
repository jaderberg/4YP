#!/bin/bash
unset DISPLAY
nohup matlab -nodesktop -nosplash -nodisplay -r "try,$1($2,$3,'$4','$5'),catch err,f=fopen('error_logs/$2-$1-error.txt','w');fprintf(f,err.message);fclose(f);exit,end,exit" -logfile matlab_logs/matlab_log$2.txt > nohup_logs/nohup$2.out 2>&1 &