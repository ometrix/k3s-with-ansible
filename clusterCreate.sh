#!/bin/bash

source var_file

# concatenate arrays

# Function to copy scripts
copy_combustion_script () {

	n=$1
	file=$2
	# load the total arrays of the HA script the second time the funtion is called
	files_created=${tHANodes[@]}

	for ((i=1; i<=n; i++)); do

			#Create a variable for the files that are passed as argument to the fuction
		script_file_ha="$file${i}"
			#Copy an rename the file to edit later
    	cp "$file" $script_file_ha
    		#Create an array of the new files created
    	files_created+=("$script_file_ha")
	done

		#Return the array of files created as result
	echo "${files_created[@]}"
}

edit_combustion_script () {

	n=$1
	#local variable to use for the script editing
	local scriptToMod=("${tNodes[@]}")

	for ((i=0; i<n; i++)); do

		if [ $i -lt $nHA ]; then

			#awk to modify the combustion script for each instance to be launch HA

			awk -v IP="$ips$(expr $i + 1)" '{sub(/RIP/, IP); print}' ${scriptToMod[$i]} > temp.txt && mv temp.txt ${scriptToMod[$i]}

			awk -v host="$clusterNode$(expr $i + 1)" '{sub(/Rhost/, host); print}' ${scriptToMod[$i]} > temp.txt && mv temp.txt ${scriptToMod[$i]}

			awk -v token="$k3stoken" '{sub(/Rtoken/, token); print}' ${scriptToMod[$i]} > temp.txt && mv temp.txt ${scriptToMod[$i]}

			awk -v IP="$masterIP" '{sub(/Rmaster/, IP); print}' ${scriptToMod[$i]} > temp.txt && mv temp.txt ${scriptToMod[$i]}

		else

			#awk to modify the combustion script for each instance to be launch WORKER

			awk -v IP="$ips$(expr $i + 1)" '{sub(/RIP/, IP); print}' ${scriptToMod[$i]} > temp.txt && mv temp.txt ${scriptToMod[$i]}

			awk -v host="$clusterNodeW$(expr $i - $nHA + 1)" '{sub(/Rhost/, host); print}' ${scriptToMod[$i]} > temp.txt && mv temp.txt ${scriptToMod[$i]}

			awk -v token="$k3stoken" '{sub(/Rtoken/, token); print}' ${scriptToMod[$i]} > temp.txt && mv temp.txt ${scriptToMod[$i]}

			awk -v IP="$masterIP" '{sub(/Rmaster/, IP); print}' ${scriptToMod[$i]} > temp.txt && mv temp.txt ${scriptToMod[$i]}

		fi

done
}

# Check if the correct number of arguments is provided

if [ $# -ne 2 ]; then
    echo "Usage: $0 <number_of_ha_nodes> <number_of_worker>"
    exit 1
fi

# In variables, $1 is number of HA node, $2 number of workers
nHA=$1
nWorker=$2
tCluster=$(expr $1 + $2)

#Script files to modify

cp script-bk/combustion-scriptha.bk combustion-script-ha
cp script-bk/combustion-scriptworker.bk combustion-script-worker
cp script-bk/combustion-script-master.bk combustion-script-master

masterScript=combustion-script-master
haScript=combustion-script-ha
workerScript=combustion-script-worker

# Check if the script file exists

if [ ! -f "$masterScript" ] || [ ! -f "$haScript" ] || [ ! -f "$workerScript" ]; then
    echo "One of the source file was not found."
    exit 1
fi

# Perform the copy using a function

tHANodes=($(copy_combustion_script $nHA $haScript))

tWorkerNodes=($(copy_combustion_script $nWorker $workerScript ${tHANodes[@]}))

tNodes=("${tWorkerNodes[@]}")

# Replace data in the script
	# Master
awk -v IP="$masterIP" '{sub(/RIPMaster/, IP); print}' $masterScript > temp.txt && mv temp.txt $masterScript
awk -v host="$clusterNode" '{sub(/RhostM/, host); print}' $masterScript > temp.txt && mv temp.txt $masterScript
awk -v token="$k3stoken" '{sub(/Rtoken/, token); print}' $masterScript > temp.txt && mv temp.txt $masterScript

edit_combustion_script $tCluster

mv combustion-script-* files/

cat >var_ansible <<-EOF
HAk3sHost: $clusterNode
workerk3s: $clusterNodeW
vmid: $vmid
tha: $1
twk: $2
EOF

ansible-playbook MicroK3s.yaml -i inventory --user=root --private-key ~/.ssh/ansible-key



