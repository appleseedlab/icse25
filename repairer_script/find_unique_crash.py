import csv

def process_bugs(input_file, output_file):
    with open(input_file, 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile)
        bugs_group1 = set()  # Bugs from first two columns
        bugs_group2 = set()  # Bugs from third and fourth columns

        # Read each row and store bug names and call traces
        for row in reader:
            # Assuming each row has exactly four columns
            bug_group1, trace_group1, bug_group2, trace_group2 = row

            # Combine bug name and trace for uniqueness
            combined_group1 = (bug_group1, trace_group1)
            combined_group2 = (bug_group2, trace_group2)

            # Add to respective sets
            bugs_group1.add(combined_group1)
            bugs_group2.add(combined_group2)

        # Find bugs unique to each group and bugs in both groups
        unique_in_group1 = bugs_group1 - bugs_group2
        unique_in_group2 = bugs_group2 - bugs_group1
        bugs_in_both = bugs_group1 & bugs_group2

    with open(output_file, 'w', newline='', encoding='utf-8') as outfile:
        writer = csv.writer(outfile)

        # Write unique bugs from Group 1
        for bug, trace in unique_in_group1:
            writer.writerow([bug, trace, 'Group 1'])

        # Write unique bugs from Group 2
        for bug, trace in unique_in_group2:
            writer.writerow([bug, trace, 'Group 2'])

        # Write bugs present in both groups
        for bug, trace in bugs_in_both:
            writer.writerow([bug, trace, 'Both'])

# Usage
process_bugs('input.csv', 'output.csv')
