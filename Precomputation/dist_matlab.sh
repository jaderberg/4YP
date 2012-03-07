#!/bin/bash
unset DISPLAY
nohup matlab -nodesktop -nosplash -nodisplay -r "$1($2,$3,'$4','$5'),exit" -logfile matlab_logs/matlab_log$2.txt > nohup_logs/nohup$2.out 2>&1 &