#!/bin/bash

# Create the directories if they don't exist
mkdir -p /home/anon/research/repaired_reproducers/c_reproducers
mkdir -p /home/anon/research/repaired_reproducers/syz_reproducers

# Read the CSV file line by line
while IFS=, read -r description type location; do
	# Skip the header line
	if [ "$description" == "Description" ]; then
		continue
	fi

	# Determine the type and copy the file to the appropriate folder
	if [ "$type" == "C reproducer" ]; then
		cp "$location/repro.cprog" "/home/anon/research/repaired_reproducers/c_reproducers/"
	elif [ "$type" == "Syz reproducer" ]; then
		if [ -f "$location/repro.prog" ]; then
			cp "$location/repro.prog" "/home/anon/research/repaired_reproducers/syz_reproducers/"
		elif [ -f "$location/repro0" ]; then
			cp "$location/repro0" "/home/anon/research/repaired_reproducers/syz_reproducers/"
		elif [ -f "$location/repro" ]; then
			cp "$location/repro" "/home/anon/research/repaired_reproducers/syz_reproducers/"
		else
			echo "No Syz reproducer found in $location"
		fi
	else
		echo "Unknown type: $type"
	fi
done <repaired_reproducers.csv
