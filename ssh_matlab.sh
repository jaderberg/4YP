echo "Connecting to eng terminals"

for i in {36..72}
do
	SERVER=engs-station$i.eng.ox.ac.uk
	echo "Running script on $SERVER"
	expect -f ex_ssh.exp kebl3465@$SERVER multipack
done

echo "Complete!"