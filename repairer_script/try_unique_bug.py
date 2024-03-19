import csv

def read_bugs_from_csv(file_path):
    group1_bugs = set()
    group2_bugs = set()

    with open(file_path, 'r') as file:
        csv_reader = csv.reader(file)
        for row in csv_reader:
            group1_bugs.add((row[0], row[1].lstrip()))  # Removing leading spaces in call trace
            group2_bugs.add((row[2], row[3].lstrip()))

    return group1_bugs, group2_bugs

def identify_unique_and_overlapping_bugs(group1_bugs, group2_bugs):
    overlapping_bugs = group1_bugs & group2_bugs
    unique_to_group1 = group1_bugs - overlapping_bugs
    unique_to_group2 = group2_bugs - overlapping_bugs

    return unique_to_group1, unique_to_group2, overlapping_bugs

def write_bugs_to_csv(unique_to_group1, unique_to_group2, overlapping_bugs, output_file_path):
    with open(output_file_path, 'w', newline='') as file:
        csv_writer = csv.writer(file)
        csv_writer.writerow(['Unique to Group 1'])
        for bug in unique_to_group1:
            csv_writer.writerow(bug)
        
        csv_writer.writerow([])
        csv_writer.writerow(['Unique to Group 2'])
        for bug in unique_to_group2:
            csv_writer.writerow(bug)

        csv_writer.writerow([])
        csv_writer.writerow(['Overlapping Bugs'])
        for bug in overlapping_bugs:
            csv_writer.writerow(bug)

def main(file_path, output_file_path):
    group1_bugs, group2_bugs = read_bugs_from_csv(file_path)
    unique_to_group1, unique_to_group2, overlapping_bugs = identify_unique_and_overlapping_bugs(group1_bugs, group2_bugs)
    write_bugs_to_csv(unique_to_group1, unique_to_group2, overlapping_bugs, output_file_path)

# Use the main function with the path to your CSV file and output file path
main('traces.csv', 'output_traces.csv')
