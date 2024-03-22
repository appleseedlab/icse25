import csv
import numpy as np
import argparse


def parse_args():
    parser = argparse.ArgumentParser(
        description="Process CSV and calculate statistics."
    )
    parser.add_argument(
        "--change_of_summaries_csv",
        type=str,
        help="Path to the CSV file",
        required=True,
    )
    return parser.parse_args()


def calculate_percentage_changes(file_path):
    values = []
    with open(file_path, "r", encoding="utf-8-sig") as csv_file:
        csv_reader = csv.reader(csv_file)

        # Skip the header or the first two rows
        next(csv_reader)
        next(csv_reader)

        for row in csv_reader:
            try:
                # Assuming column 3 is indexed as 2 (0-indexed)
                value = float(row[2])
                percentage_change = (value / 19394) * 100
                values.append(percentage_change)
            except (IndexError, ValueError):
                # Handle the case where the row might not have enough columns or the data can't be converted to float
                continue
    return values


def calculate_statistics(values):
    statistics = {
        "min": np.min(values),
        "25th_percentile": np.percentile(values, 25),
        "median": np.median(values),
        "75th_percentile": np.percentile(values, 75),
        "99th_percentile": np.percentile(values, 99),
        "max": np.max(values),
    }
    return statistics


def create_pdf_table(stats):
    # Create DataFrame with stats wrapped in a list for a single-row DataFrame
    df = pd.DataFrame([stats])

    # Format the DataFrame to have percentage values with 2 decimal points
    # Ensure that the formatting is only applied to numeric values
    df = df.applymap(lambda x: f"{x:.2f}%" if isinstance(x, (int, float)) else x)

    # Set up PDF file path
    pdf_file_path = "change_summary.pdf"

    # Save the table as a PDF with specific borders under column headers and to the right of row headers
    with PdfPages(pdf_file_path) as pdf:
        fig, ax = plt.subplots(figsize=(8, 0.5))
        ax.axis("off")
        table = ax.table(
            cellText=df.values, colLabels=df.columns, loc="center", cellLoc="center"
        )
        table.auto_set_font_size(False)
        table.set_fontsize(10)
        table.auto_set_column_width(col=list(range(len(df.columns))))

        # Set all borders to zero
        for key, cell in table.get_celld().items():
            cell.set_linewidth(0)

        # Add border under the header
        for col in range(len(df.columns)):
            table[(0, col)].set_edgecolor("black")
            table[(0, col)].set_linewidth(1)
            table[(0, col)].get_text().set_weight("bold")

            if col == 0:
                table[(0, col)].visible_edges = "BR"
            else:
                table[(0, col)].visible_edges = "B"

        # # Explicitly set borders for header cells
        # for col in range(len(df.columns)):
        #     cell = table[(0, col)]
        #     cell.set_edgecolor("black")
        #     cell.set_linewidth(1)
        #     cell.set_linestyle("-")  # Ensure the line is solid
        #     # Explicitly hide top, left, and right borders if needed
        #     cell.visible_edges = "B"  # Show only the bottom edge

        # Add right border to the first column for all rows
        # Start from 1 because (0, 0) is the header cell which already has its bottom border set
        for row in range(
            1, len(df) + 1
        ):  # Adjust +1 if your DataFrame has more than one row
            cell = table[(row, 0)]
            cell.set_edgecolor("black")
            cell.set_linewidth(1)
            cell.visible_edges = "R"  # Show only the right edge
        # Save the figure to the PDF file
        pdf.savefig(fig, bbox_inches="tight")

    # Close the figure
    plt.close(fig)
def main():
    args = parse_args()
    percentage_changes = calculate_percentage_changes(args.change_of_summaries_csv)
    stats = calculate_statistics(percentage_changes)

    print(f"Minimum: {stats['min']:.2f}")
    print(f"25th Percentile: {stats['25th_percentile']:.2f}")
    print(f"Median: {stats['median']:.2f}")
    print(f"75th Percentile: {stats['75th_percentile']:.2f}")
    print(f"99th Percentile: {stats['99th_percentile']:.2f}")
    print(f"Maximum: {stats['max']:.2f}")

    create_pdf_table(stats)


if __name__ == "__main__":
    main()
