import numpy as np
import matplotlib.pyplot as plt

# Data preparation: combining all times
all_times = np.array([
    43.84, 45.05, 43.43, 44.87, 43.52, 44.73, 44.03, 45.41, 45.56, 44.77,
    43.50, 44.17, 42.49, 43.37, 171.51, 43.16, 44.17, 39.48, 43.81, 171.41,
    44.36, 44.15, 170.12, 43.57, 171.40, 172.46, 43.92, 45.19, 169.97, 43.78,
    42.14, 171.94, 43.94, 171.38, 171.89, 43.51, 43.91, 172.99, 43.00, 44.86,
    43.78, 171.14, 172.95, 43.40, 172.08, 44.97, 43.05, 172.57, 43.29, 170.09
])

# Sort data
sorted_times = np.sort(all_times)
cdf = np.arange(len(sorted_times)) / float(len(sorted_times))

# Create CDF plot
plt.figure(figsize=(10, 6))
plt.plot(sorted_times, cdf, marker='.', linestyle='none')
plt.xlabel('Time Taken (seconds)')
plt.ylabel('Cumulative Probability')
plt.title('CDF of Configuration File Repair Times')
plt.grid(True)
plt.show()

