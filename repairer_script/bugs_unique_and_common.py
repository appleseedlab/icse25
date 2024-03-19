import csv

# Initialize empty sets for each column
column_1_bugs = set()
column_2_bugs = set()

# Read CSV file and populate the sets
with open('all_bugs.csv', 'r') as csvfile:
    csvreader = csv.reader(csvfile)
    next(csvreader, None)  # Skip the header if it exists
    for row in csvreader:
        column_1_bugs.add(row[0])
        column_2_bugs.add(row[1])

# Find unique bugs for each column and common bugs
unique_column_1_bugs = column_1_bugs - column_2_bugs
unique_column_2_bugs = column_2_bugs - column_1_bugs
common_bugs = column_1_bugs & column_2_bugs

# Write the results to a new CSV file
with open('all_bugs_results.csv', 'w', newline='') as csvfile:
    csvwriter = csv.writer(csvfile)
    
    csvwriter.writerow(['Unique bugs in Column 1'])
    for bug in unique_column_1_bugs:
        csvwriter.writerow([bug])

    csvwriter.writerow([])
    csvwriter.writerow(['Unique bugs in Column 2'])
    for bug in unique_column_2_bugs:
        csvwriter.writerow([bug])

    csvwriter.writerow([])
    csvwriter.writerow(['Common bugs in both columns'])
    for bug in common_bugs:
        csvwriter.writerow([bug])
