#!/bin/bash
matlab -nodesktop -nosplash -r "$1($2,$3,'$4','$5');exit" -logfile matlab_log$2.txt