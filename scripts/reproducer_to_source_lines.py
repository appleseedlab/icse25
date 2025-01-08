import subprocess
import argparse
import re

def deduplicate_and_filter_lines(input_lines):
    # Deduplicate and filter out .h files, remove line numbers
    unique_files = set()
    for line in input_lines:
        file_path = line.split(':')[0]  # Split and take the file path part
        if not file_path.endswith('.h'):
            unique_files.add(file_path)
    return list(unique_files)

def parse_klocalizer_output(output):
    # Extract configuration options from klocalizer output
    config_options = set()
    for line in output.split('\n'):
        match = re.findall(r'CONFIG_[A-Z0-9_]+', line)
        config_options.update(match)
    return config_options

def run_klocalizer(file_paths):
    results = {}
    all_configs = set()
    for file_path in file_paths:
        cmd = f"klocalizer --view-kbuild --include {file_path}"
        try:
            # Execute the command and capture output
            output = subprocess.check_output(cmd, shell=True, text=True)
            config_options = parse_klocalizer_output(output)
            results[file_path] = config_options
            all_configs.update(config_options)
        except subprocess.CalledProcessError as e:
            results[file_path] = f"Error while running klocalizer: {e}"
    return results, all_configs

def save_results(results, output_file):
    with open(output_file, 'w') as file:
        for file_path, config in results.items():
            file.write(f"File: {file_path}\n")
            file.write("Kernel Configuration Options:\n")
            file.write('\n'.join(config) + "\n\n")

def check_configurations(configurations, config_file):
    enabled_configs = set()
    disabled_configs = set()
    with open(config_file, 'r') as file:
        lines = file.read()
        for config in configurations:
            if f'{config}=y' in lines:
                enabled_configs.add(config)
            else:
                disabled_configs.add(config)
    return enabled_configs, disabled_configs

def main(addr2line_file, output_file, syzkaller_config, repaired_config):
    with open(addr2line_file, 'r') as file:
        addr2line_output = file.readlines()

    # Deduplicate and filter the lines
    unique_files = deduplicate_and_filter_lines(addr2line_output)

    # Run klocalizer for each file
    results, all_configs = run_klocalizer(unique_files)

    # Print the results and save them to a file
    for file_path, config in results.items():
        print(f"File: {file_path}")
        print("Kernel Configuration Options:", config)
    
    save_results(results, output_file)

    # Check configurations in the provided syzkaller config
    enabled_configs, disabled_configs = check_configurations(all_configs, syzkaller_config)
    print("Enabled configurations in the syzkaller config file:", enabled_configs)
    print("Disabled configurations in the syzkaller config file:", disabled_configs)

    # Check configurations in the provided repaired config
    enabled_configs_repaired, disabled_configs_repaired = check_configurations(all_configs, repaired_config)
    print("Enabled configurations in the repaired config file:", enabled_configs_repaired)
    print("Disabled configurations in the repaired config file:", disabled_configs_repaired)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process addr2line output and run klocalizer.")
    parser.add_argument("--addr2line-file", required=True, help="Path to the file containing addr2line output")
    parser.add_argument("--output-file", required=True, help="Path to the output file for saving results")
    parser.add_argument("--syzkaller-config", required=True, help="Path to the syzkaller .config file")
    parser.add_argument("--repaired-config", required=True, help="Path to the repaired .config file")

    args = parser.parse_args()
    main(args.addr2line_file, args.output_file, args.syzkaller_config, args.repaired_config)
