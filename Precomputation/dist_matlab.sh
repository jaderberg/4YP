#!/bin/bash
nohup matlab -nodesktop -nosplash -r "$1($2,$3,'$4','$5'),exit" -logfile matlab_log$2.txt > nohup$2.out 2>&1 &