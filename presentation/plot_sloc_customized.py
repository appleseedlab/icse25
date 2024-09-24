import pandas as pd
import matplotlib.pyplot as plt
import sys
import re

# Function to extract major and minor versions from tag
def extract_version_tuple(tag):
    # Extract the major and minor version numbers using regex
    version = re.findall(r'v(\d+)\.(\d+)', tag)
    if version:
        major, minor = version[0]
        return (int(major), int(minor))  # Return as tuple of integers for sorting
    return (0, 0)  # Return a default value in case no match

# Check if the user has provided a CSV file path
if len(sys.argv) != 2:
    print("Usage: python script.py <path_to_csv_file>")
    sys.exit(1)

# Get the CSV file path from command line argument
csv_file = sys.argv[1]

# Load the CSV file into a pandas DataFrame
df = pd.read_csv(csv_file, header=None, names=['Tag', 'SLOC'])

# Convert the SLOC column to integers (in case they are read as strings)
df['SLOC'] = pd.to_numeric(df['SLOC'], errors='coerce')

# Extract version tuples from tags and sort by the version (major, minor)
df['VersionTuple'] = df['Tag'].apply(extract_version_tuple)
df = df.sort_values('VersionTuple')

# Plot the data
plt.figure(figsize=(12, 8))

# Customize line plot with color and markers
plt.plot(df['Tag'], df['SLOC'], marker='o', linestyle='-', color='darkblue',
         markerfacecolor='red', markeredgewidth=2, markersize=8, label='SLOC Growth')

# Set labels and title with increased font size and boldness
plt.xlabel('Linux Version Tags', fontsize=14, fontweight='bold')
plt.ylabel('Source Lines of Code (SLOC)', fontsize=14, fontweight='bold')
plt.title('Linux-Next SLOC Increase Across Stable Versions', fontsize=16, fontweight='bold')

# Rotate x-axis labels for better readability
plt.xticks(rotation=45, ha='right', fontsize=10)

# Add grid for better visualization
plt.grid(True, which='both', linestyle='--', linewidth=0.5)

# Annotate the first and last data points
plt.annotate(f"{df['SLOC'].iloc[0]} SLOC",
             (df['Tag'].iloc[0], df['SLOC'].iloc[0]),
             xytext=(-10, 10), textcoords='offset points', arrowprops=dict(arrowstyle='->', color='black'))

plt.annotate(f"{df['SLOC'].iloc[-1]} SLOC",
             (df['Tag'].iloc[-1], df['SLOC'].iloc[-1]),
             xytext=(-10, -15), textcoords='offset points', arrowprops=dict(arrowstyle='->', color='black'))

# Add a legend
plt.legend()

# Save the plot as a PDF file
output_pdf = 'linux_sloc_trend_customized.png'
plt.tight_layout()
plt.savefig(output_pdf, format='png')

# Show the plot
plt.show()

print(f"Plot saved as {output_pdf}")

