import csv
import numpy as np

# Get csv file from cli
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--file", help="csv file to read")
args = parser.parse_args()

# Read the data from the CSV file
filename = args.file
build_times = []

with open(filename, 'r') as csvfile:
    reader = csv.reader(csvfile)
    for row in reader:
        build_time = float(row[3])
        build_times.append(build_time)

# Convert to a numpy array for easier calculations
build_times = np.array(build_times)

# Calculate the five-number summary
minimum = np.min(build_times)
Q1 = np.percentile(build_times, 25)
median = np.median(build_times)
Q3 = np.percentile(build_times, 75)
maximum = np.max(build_times)

# Print the five-number summary
print(f"Minimum: {minimum}")
print(f"First Quartile (Q1): {Q1}")
print(f"Median: {median}")
print(f"Third Quartile (Q3): {Q3}")
print(f"Maximum: {maximum}")

