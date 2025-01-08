#!/bin/bash

# Initialize CSV file with header
echo "Description,Type,Location" >reproducers.csv

# Function to process each directory
process_dir() {
	local dir=$1
	local desc_file="${dir}/description"
	local csv_entry=""

	if [[ -f "$desc_file" ]]; then
		local description=$(cat "$desc_file")
		csv_entry+="${description},"

		if [[ -f "${dir}/repro.cprog" ]]; then
			csv_entry+="C reproducer,"
		elif [[ -f "${dir}/repro0" ]] || [[ -f "${dir}/repro" ]] || [[ -f "${dir}/repro.prog" ]]; then
			csv_entry+="Syz reproducer,"
		else
			return
		fi

		csv_entry+="${dir}"
		echo "$csv_entry" >>reproducers.csv
	fi
}

# Start recursion from repaired_bugs folder
export -f process_dir
find repaired_bugs -type d -exec bash -c 'process_dir "$0"' {} \;
