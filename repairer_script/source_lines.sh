#!/bin/bash

# Path to the kernel directory containing .c and .i files
KERNEL_DIR=$1

# Check if the kernel directory is provided
if [[ -z "$KERNEL_DIR" ]]; then
    echo "Usage: $0 <kernel_directory>"
    echo "Example: $0 /path/to/linux-next"
    exit 1
fi

# Check if the kernel directory exists
if [[ ! -d "$KERNEL_DIR" ]]; then
    echo "Kernel directory not found"
    exit 1
fi

# Navigate to the kernel directory
cd "$KERNEL_DIR" || {
	echo "Kernel directory not found"
	exit 1
}

# Find all .c files in the kernel directory and its subdirectories
find . -type f -name "*.c" | while IFS= read -r c_file; do
	# Construct the corresponding .i file name
	i_file="${c_file%.c}.i"

	# Check if the .i file exists
	if [[ -f "$i_file" ]]; then
		# Construct the output file name
		output_file="${c_file%.c}_source_lines.txt"
		echo "Processing $c_file -> $output_file"

		# Define the pattern to match the .c file within the .i file
		pattern=$(basename "$c_file")

		# Execute awk command with the pattern to extract relevant lines
		awk -v pattern="$pattern" '
        /# [0-9]+ ".*\/'"$pattern"'"/ {print_it = 1; next}
        /^# [0-9]+ ".*"/ {print_it = 0}
        print_it {print}
        ' "$i_file" >"$output_file"

		# Check if the output file is non-empty
		if [[ -s "$output_file" ]]; then
			echo "Output written to $output_file"
		else
			echo "No matching lines found in $i_file. Deleting empty output file."
			rm -f "$output_file"
		fi
	else
		# If the .i file does not exist, output a message
		echo "No .i file for $c_file"
	fi
done
