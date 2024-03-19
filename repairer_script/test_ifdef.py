import subprocess
import sys

def run_cscope_search(function_name):
    try:
        command = ["cscope", "-d", "-L1", function_name]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error running cscope: {e}")
        return ""

def is_function_inside_ifdef(file_path, line_number):
    ifdef_stack = []
    with open(file_path, 'r') as file:
        for i, line in enumerate(file):
            if i + 1 >= line_number:
                break
            line = line.strip()
            if line.startswith('#ifdef') or line.startswith('#ifndef'):
                ifdef_stack.append(line)
            elif line.startswith('#endif'):
                if ifdef_stack:
                    ifdef_stack.pop()
    return bool(ifdef_stack)

def parse_cscope_output(cscope_output):
    for line in cscope_output.split('\n'):
        if line.strip():
            parts = line.split()
            if len(parts) >= 3:
                file_path = parts[0]
                try:
                    line_number = int(parts[2])
                    return file_path, line_number
                except ValueError:
                    continue
    return None, None

def main():
    if len(sys.argv) != 2:
        print("Usage: python test_script.py [function_name]")
        return

    function_name = sys.argv[1]
    cscope_output = run_cscope_search(function_name)

    file_path, line_number = parse_cscope_output(cscope_output)
    if file_path is None or line_number is None:
        print(f"No valid cscope output for function: {function_name}")
        return

    print(f"Function '{function_name}' is defined in: {file_path}")
    
    if is_function_inside_ifdef(file_path, line_number):
        print(f"The function '{function_name}' is inside an #ifdef.")
    else:
        print(f"The function '{function_name}' is not inside an #ifdef.")

if __name__ == "__main__":
    main()
