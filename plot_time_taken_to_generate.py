import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

# Data preparation
all_times = np.array([
    43.84, 45.05, 43.43, 44.87, 43.52, 44.73, 44.03, 45.41, 45.56, 44.77,
    43.50, 44.17, 42.49, 43.37, 171.51, 43.16, 44.17, 39.48, 43.81, 171.41,
    44.36, 44.15, 170.12, 43.57, 171.40, 172.46, 43.92, 45.19, 169.97, 43.78,
    42.14, 171.94, 43.94, 171.38, 171.89, 43.51, 43.91, 172.99, 43.00, 44.86,
    43.78, 171.14, 172.95, 43.40, 172.08, 44.97, 43.05, 172.57, 43.29, 170.09
])

# Calculate summary statistics
summary_stats = {
    'Minimum': np.min(all_times),
    'Maximum': np.max(all_times),
    'Median': np.median(all_times),
    '25th Percentile (Q1)': np.percentile(all_times, 25),
    '75th Percentile (Q3)': np.percentile(all_times, 75),
    '90th Percentile': np.percentile(all_times, 90)
}

# Create DataFrame
summary_stats_df = pd.DataFrame(list(summary_stats.items()), columns=['Statistic', 'Value'])

# Create a PDF file
pdf_file = "plot_time_taken.pdf"

with PdfPages(pdf_file) as pdf:
    # Create a figure for the table
    fig, ax = plt.subplots(figsize=(8, 4))  # Adjust the size as needed
    ax.axis('tight')
    ax.axis('off')
    table = ax.table(cellText=summary_stats_df.values, colLabels=summary_stats_df.columns, cellLoc='center', loc='center')

    # Add the table to the PDF
    pdf.savefig(fig)

print(f"Summary statistics table saved to {pdf_file}")

