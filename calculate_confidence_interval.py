import numpy as np
import scipy.stats
import argparse
import matplotlib.pyplot as plt


def parse_args():
    parser = argparse.ArgumentParser(description="Calculate confidence interval")
    parser.add_argument(
        "--syzkaller_file", type=str, help="Path to the syzkaller file with the data"
    )
    parser.add_argument(
        "--krepair_file", type=str, help="Path to the krepair file with the data"
    )
    parser.add_argument(
        "--confidence", type=float, default=0.95, help="Confidence level"
    )
    return parser.parse_args()


