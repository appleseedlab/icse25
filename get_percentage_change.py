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


if __name__ == "__main__":
    main()
