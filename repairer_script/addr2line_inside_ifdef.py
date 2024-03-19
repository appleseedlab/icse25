def read_file(file_path):
    with open(file_path, 'r') as file:
        return set(file.read().splitlines())

def find_diff(file1, file2):
    return file1 - file2, file2 - file1

def is_inside_ifdef(file_path, line_number):
    with open(file_path, 'r') as file:
        lines = file.readlines()
        ifdef_count = 0
        for i in range(line_number - 1):
            line = lines[i].strip()
            if line.startswith('#ifdef') or line.startswith('#if'):
                ifdef_count += 1
            elif line.startswith('#endif'):
                ifdef_count -= 1
        return ifdef_count > 0

def main(file1_path, file2_path):
    file1_lines = read_file(file1_path)
    file2_lines = read_file(file2_path)

    diff1, diff2 = find_diff(file1_lines, file2_lines)

    for line in diff1.union(diff2):
        file_path, line_number = line.rsplit(':', 1)
        if is_inside_ifdef(file_path, int(line_number)):
            print(f"{line} is inside an #ifdef block")
        else:
            print(f"{line} is not inside an #ifdef block")

# Replace 'file1.txt' and 'file2.txt' with your actual file paths
main('file1.txt', 'file2.txt')
