#ssh -X -l kebl3465 engs-station39.eng.ox.ac.uk '(cd 4YP && matlab -nodesktop -nosplash -r test)'

# The following line auto enters the password
#expect -c 'spawn ssh -X -l kebl3465 engs-station39.eng.ox.ac.uk "(cd 4YP && matlab -nodesktop -nosplash -r test)" ; expect assword ; send "multipack\n" ; interact'

NUM=38
EXCMD='spawn ssh -X -l kebl3465 engs-station'$NUM'.eng.ox.ac.uk "(cd 4YP && matlab -nodesktop -nosplash -r test)" ; expect assword ; send "multipack\n" ; interact'
echo $EXCMD

echo $EXCMD | expect -c
