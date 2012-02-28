#!/bin/bash
matlab -nodesktop -nosplash -r "try,$1($2,$3),catch err,f=fopen('error$2.txt','w');fprintf(f,err.message);fclose(f);exit,end,exit" -logfile matlab_log$2.txt