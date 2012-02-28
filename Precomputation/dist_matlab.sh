#!/bin/bash
matlab -nodesktop -nosplash -r "try,$1($2,$3);exit" -logfile matlab_log$2.txt