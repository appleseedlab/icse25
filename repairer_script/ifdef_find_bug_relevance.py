import re
import argparse
import subprocess
import os

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

def check_config_option_in_file(config_option, file_path):
    with open(file_path, 'r') as file:
        for line in file:
            if line.startswith(config_option) and not line.startswith('#'):
                return True
    return False

def find_kernel_config_for_file(args, file_path, klocalizer_path):
    #print("inside klocalizer")
    command = f"{klocalizer_path} --view-kbuild --include {file_path}"
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        debug_print(args, f"Running command: {command}")
        debug_print(args, f"Command output: {result.stdout}")
        debug_print(args, f"Command error: {result.stderr}")
        if result.returncode != 0:
            print(f"Error running klocalizer for {file_path}: {result.stderr}")
            return None

        return parse_klocalizer_output(result.stdout)
    except Exception as e:
        print(f"An error occurred while running klocalizer: {e}")
        return None

def checkout_to_git_tag(args, git_tag):
    
    command = f"git checkout -f {git_tag}"
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        debug_print(args, f"Running command: {command}")
        debug_print(args, f"Command output: {result.stdout}")
        debug_print(args, f"Command error: {result.stderr}")

        if result.returncode != 0:
            print(f"Command failed: {result.stderr}")
    except Exception as e:
        print(f"An error occurred while running this command: {e}")

def source_kmax(args):
    
    command = f"source ~/env_kmax/bin/activate"
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, executable='/usr/bin/zsh')
        debug_print(args, f"Running command: {command}")
        #debug_print(f"Command output: {result.stdout}")
        #debug_print(f"Command error: {result.stderr}")

        if result.returncode != 0:
            print(f"Command failed: {result.stderr}")
    except Exception as e:
        print(f"An error occurred while running this command: {e}")
    

def parse_klocalizer_output(output):
    config_options = []
    lines = output.split('\n')

    pattern = re.compile(r'\[([^\]]+)\]')

    for line in lines:
        match = pattern.search(line)
        if match:
            options_str = match.group(1)
            # Split the options by commas, while considering 'Or' and 'And' expressions
            options = re.split(r'\s*,\s*(?![^()]*\))', options_str)
            config_options.extend(options)
    
    # Remove potential duplicates and return the list
    return list(set(config_options))

def find_function_definitions(functions, src_dir):
    function_defs = {}
    for function in functions:
        command = f'cscope -dL -1 {function}'
        result = subprocess.run(command, shell=True, capture_output=True, text=True, cwd=src_dir)

        if result.returncode == 0 and result.stdout:
            lines = result.stdout.strip().split('\n')
            function_info = []
            for line in lines:
                parts = line.split()
                if len(parts) >= 3:
                    file_path = parts[0]
                    try:
                        line_number = int(parts[2])
                        inside_ifdef = is_function_inside_ifdef(os.path.join(src_dir, file_path), line_number)
                        function_info.append((file_path, inside_ifdef))
                    except ValueError:
                        continue
            function_defs[function] = function_info
        else:
            function_defs[function] = []  # No definition found or error occurred
    return function_defs

def parse_bug_report(bug_report):
    call_trace = []
    trace_start = False
    trace_end = False
    for line in bug_report.splitlines():
        if '<TASK>' in line:
            trace_start = True
            continue
        if '</TASK>' in line:
            trace_end = True
        if 'Allocated by task':
            trace_end = False
        if '-> #':
            trace_start = True
            
        if trace_start:
            if trace_end != True:
                call_trace.append(line.strip())
    return call_trace

def extract_functions(call_trace):
    functions = []
    # Example pattern: matches 'function_name' before a '+' sign and ignores the rest
    pattern = re.compile(r'(\w+)\+')

    for line in call_trace:
        match = pattern.search(line)
        if match:
            functions.append(match.group(1))  # Group 1 contains the function name
    return functions

def find_kernel_config_options(functions, function_to_config_mapping):
    config_options = set()
    for function in functions:
        if function in function_to_config_mapping:
            config_options.add(function_to_config_mapping[function])
    return config_options

def debug_print(args, *print_args, **print_kwargs):
    if args.debug:
        print(*print_args, **print_kwargs)

def main():
    parser = argparse.ArgumentParser(description="Process a syzkaller bug report to find kernel configuration options.")
    parser.add_argument('--bug-report', type=str, required=True, help='Path to the syzkaller bug report file')
    parser.add_argument('--default-config', type=str, required=True, help='Path to the default kernel configuration file')
    parser.add_argument('--repaired-config', type=str, required=True, help='Path to the repaired kernel configuration file')
    parser.add_argument('--git-tag', type=str, required=True, help='Git tag to checkout to')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')

    args = parser.parse_args()

    with open(args.bug_report, 'r') as file:
        bug_report = file.read()

    call_trace = parse_bug_report(bug_report)
    functions = extract_functions(call_trace)

    print(call_trace)
    print(functions)
    print("Calling checkout to git tag...")
    checkout_to_git_tag(args, args.git_tag)
    source_kmax(args)

    src_dir = "/home/m4st3rm1nd/linux-next"  # Replace with the actual path
    klocalizer_path = "klocalizer"
    function_defs = find_function_definitions(functions, src_dir)
    print("Function Definitions:", function_defs)

    default_config_path = args.default_config
    repaired_config_path = args.repaired_config

    all_config_options = {}
    for function, file_info_list in function_defs.items():
        if file_info_list:
            for file_info in file_info_list:
                file_path, inside_ifdef = file_info
                if inside_ifdef:
                    print(f"\033[92mThe function '{function}' that is defined in the source file '{file_path}' is inside an #ifdef!!!\033[0m")
                if file_path.endswith('.c') or file_path.endswith('.o'):
                    print(f"Processing {file_path} for function {function}")
                    config_options = find_kernel_config_for_file(args, file_path, klocalizer_path)
                    if config_options:
                        all_config_options[file_path] = config_options
                    else:
                        print(f"No configuration options found for {file_path}")

    print("Kernel Configuration Options for Files:", all_config_options)

    for file, options in all_config_options.items():
        for option in options:
            exists_in_default = check_config_option_in_file(option, default_config_path)
            exists_in_repaired = check_config_option_in_file(option, repaired_config_path)
            if (exists_in_repaired == True and exists_in_default == False):
                print(f"[+] {option} only exists in repaired config")
            elif (exists_in_default == True and exists_in_repaired == False):
                print(f"[-] {option} only exists in default config")
            print(f"{option} in {file}: Default Config - {exists_in_default}, Repaired Config - {exists_in_repaired}")

if __name__ == "__main__":
    main()
