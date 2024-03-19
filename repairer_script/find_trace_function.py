import re

# Sample line from the Call Trace section
line = " file_tty_write.constprop.0+0x472/0x9c0 drivers/tty/tty_io.c:1089"

# Regular expression pattern to match function call and offset
pattern = re.compile(r" (\w+(?:\.\w+)*)(?:\+[0-9a-fx]+/[0-9a-fx]+)? ([^:]+):(\d+)")

# Apply regex
match = pattern.search(line)
if match:
    function_name = match.group(1)
    source_file = match.group(2)
    line_number = match.group(3)
    print(f"Function: {function_name}, Source File: {source_file}, Line Number: {line_number}")
