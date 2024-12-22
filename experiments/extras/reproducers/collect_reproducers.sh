#!/bin/bash

if [[ $# -ne 3 ]]; then
    echo "[*] Usage: ./program <path-to-repaired-reproducers-directory> <path-to-csv-containing-paths-to-repaired-reproducers> <repaired_bugs_directory>"
    echo "[*] Example: ./collect_reproducers.sh ./repaired_reproducers/ ./repaired_reproducers.csv ./repaired_bugs/"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$SCRIPT_DIR/../../../"
echo "Root directory: $ROOT_DIR"

repaired_reproducers="$ROOT_DIR/$1"
repaired_reproducers_csv="$ROOT_DIR/$2"
repaired_bugs="$ROOT_DIR/$3"

echo "Repaired reproducers directory: $repaired_reproducers"
echo "Repaired reproducers CSV file: $repaired_reproducers_csv"
echo "Repaired bugs directory: $repaired_bugs"

c_reproducers="$repaired_reproducers/c_reproducers"
syz_reproducers="$repaired_reproducers/syz_reproducers"

# Create the directories if they don't exist
mkdir -p $c_reproducers
mkdir -p $syz_reproducers

# Replace "/home/sanan/research/guild_bugs" with the new folder
cp "$repaired_reproducers_csv" "${repaired_reproducers_csv}.bak"
sed -i "s|/home/anon/research/guild_bugs|$repaired_bugs|g" "$repaired_reproducers_csv"

# Read the CSV file line by line
while IFS=, read -r description type location; do
	# Skip the header line
	if [ "$description" == "Description" ]; then
		continue
	fi

    folder_name=$(echo "$location" | sed "s|$repaired_bugs||" | sed 's|/crashes/.*||')

	# Determine the type and copy the file to the appropriate folder
	if [ "$type" == "C reproducer" ]; then
		cp "$location/repro.cprog" "$c_reproducers/${folder_name}_repro.cprog"
	elif [ "$type" == "Syz reproducer" ]; then
		if [ -f "$location/repro.prog" ]; then
			cp "$location/repro.prog" "$syz_reproducers/${folder_name}_repro.prog"
		elif [ -f "$location/repro0" ]; then
			cp "$location/repro0" "$syz_reproducers/${folder_name}_repro.prog"
		elif [ -f "$location/repro" ]; then
			cp "$location/repro" "$syz_reproducers/${folder_name}_repro.prog"
		else
			echo "No Syz reproducer found in $location"
		fi
	else
		echo "Unknown type: $type"
	fi
done <$repaired_reproducers_csv

cp "${repaired_reproducers_csv}.bak" "$repaired_reproducers_csv"
