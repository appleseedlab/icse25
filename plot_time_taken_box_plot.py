import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np

# Data preparation
all_times = np.array([
    43.84, 45.05, 43.43, 44.87, 43.52, 44.73, 44.03, 45.41, 45.56, 44.77,
    43.50, 44.17, 42.49, 43.37, 171.51, 43.16, 44.17, 39.48, 43.81, 171.41,
    44.36, 44.15, 170.12, 43.57, 171.40, 172.46, 43.92, 45.19, 169.97, 43.78,
    42.14, 171.94, 43.94, 171.38, 171.89, 43.51, 43.91, 172.99, 43.00, 44.86,
    43.78, 171.14, 172.95, 43.40, 172.08, 44.97, 43.05, 172.57, 43.29, 170.09
])

# Create box plot with swarm plot
plt.figure(figsize=(12, 6))
sns.boxplot(data=all_times, orient='h', color='lightblue')
sns.swarmplot(data=all_times, orient='h', color='blue', size=5)
plt.xlabel('Time Taken (seconds)')
plt.title('Box Plot with Swarm Plot of Configuration File Repair Times')
plt.show()

