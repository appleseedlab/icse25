from datetime import datetime, timedelta
import matplotlib.pyplot as plt

tool_1_times = [
    "2:10:45", "3:17:29", "6:45:08", "11:07:22", "3:12:53", "4:42:44", "4:25:18", 
    "4:42:21", "7:54:11", "9:52:50", "7:29:57", "0:00:01", "7:58:54", "7:20:48", 
    "9:51:05", "4:54:00", "1:27:09", "9:35:53", "11:22:58", "10:37:02", "11:21:55", 
    "2:02:30", "6:28:04", "9:47:46", "8:20:11", "9:59:24", "0:44:01", "11:33:29", 
    "3:52:56", "3:05:10", "5:47:25", "7:58:28", "6:28:24", "0:37:40", "09:08:55"
]

tool_2_times = [
    None, None, None, "6:23:46", None, None, None, None, None, "2:23:57", None, 
    "10:11:45", "4:56:20", None, None, None, None, None, None, "5:26:13", "1:44:16", 
    None, None, None, None, "2:44:56", None, None, "7:39:51", "10:45:55", None, None, 
    "4:03:09", "0:18:35", None
]

# Function to convert time string to minutes
def time_to_minutes(time_str):
    if time_str is None:
        return None
    h, m, s = map(int, time_str.split(':'))
    return h * 60 + m + s / 60

tool_1_minutes = [time_to_minutes(time) for time in tool_1_times]
tool_2_minutes = [time_to_minutes(time) for time in tool_2_times]

filtered_tool_1_minutes = [tool_1_minutes[i] for i in range(len(tool_1_minutes)) if tool_2_minutes[i] is not None]
filtered_tool_2_minutes = [time for time in tool_2_minutes if time is not None]

plt.figure(figsize=(10, 6))
plt.scatter(filtered_tool_1_minutes, filtered_tool_2_minutes,marker='x', color='blue', alpha=0.7, s=100)

plt.xlim(left=0, right=700)
plt.ylim(bottom=0)

plt.xlabel('Time Taken by KonfFuzz (minutes)', fontsize=18)
plt.ylabel('Time Taken by Syzkaller (minutes)', fontsize=18)
plt.tick_params(axis='both', which='major', labelsize=14)
plt.grid(True)

pdf_filename = 'time_comparison_chart.pdf'
plt.savefig(pdf_filename)
