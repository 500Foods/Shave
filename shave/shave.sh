#!/bin/bash
# Shave: A Bash-to-C transpiler for converting Bash scripts to C executables.

# CHANGELOG
# Version 0.1.0 - 2025-07-05 - Initial setup of Shave transpiler.

# Script metadata
SCRIPT_NAME="shave"
SCRIPT_VERSION="0.1.0"

# Display help information
show_help() {
    log_output "info" "Usage: $SCRIPT_NAME [options] <input_bash_script>"
    log_output "info" "Convert a Bash script to a C executable."
    log_output "info" ""
    log_output "info" "Options:"
    log_output "info" "  -h, --help            Display this help message and exit."
    log_output "info" "  -o, --output <file>   Specify the output C executable name."
    log_output "info" "                        Defaults to input script name without extension,"
    log_output "info" "                        or appends '.exe' if no extension exists."
    log_output "info" "  -k, --keep            Keep the generated C source file after compilation."
    log_output "info" ""
    log_output "info" "Example:"
    log_output "info" "  $SCRIPT_NAME myscript.sh"
    log_output "info" "  $SCRIPT_NAME -o myprogram myscript.sh"
    exit 0
}

# Set the start time at the very beginning of the script
export SHAVE_START_TIME
SHAVE_START_TIME=$(date +%s%3N)
# Source modular components using the script's directory
SCRIPT_DIR=""
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Source shave-output.sh first to ensure log_output is available
# shellcheck source=./shave-output.sh
. "$SCRIPT_DIR/shave-output.sh"
log_output "init" "Initializing $SCRIPT_NAME $SCRIPT_VERSION"
log_output "step" "Sourcing scripts"
# shellcheck source=./shave-boilerplate.sh
# shellcheck source=./shave-compiler.sh
# shellcheck source=./shave-parser.sh
for script in "$SCRIPT_DIR/shave-boilerplate.sh" "$SCRIPT_DIR/shave-compiler.sh" "$SCRIPT_DIR/shave-parser.sh"; do
    if [ -f "$script" ]; then
        log_output "info" "Sourcing $script"
        . "$script"
    else
        log_output "fail" "Script $script not found!"
        exit 1
    fi
done

# Check if functions are available
if ! type generate_c_boilerplate >/dev/null 2>&1; then
    log_output "fail" "Function generate_c_boilerplate not found. Sourcing failed."
    exit 1
fi
if ! type parse_bash_to_c >/dev/null 2>&1; then
    log_output "fail" "Function parse_bash_to_c not found. Sourcing failed."
    exit 1
fi
if ! type compile_c_to_executable >/dev/null 2>&1; then
    log_output "fail" "Function compile_c_to_executable not found. Sourcing failed."
    exit 1
fi
log_output "pass" "All functions sourced successfully."

# Placeholder for output filename logic
output_file=""
keep_c_file="false"

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -o|--output)
            if [[ -n "$2" ]]; then
                output_file="$2"
                shift 2
            else
                log_output "fail" "Output file name not specified."
                exit 1
            fi
            ;;
        -k|--keep)
            keep_c_file="true"
            shift
            ;;
        *)
            input_file="$1"
            shift
            ;;
    esac
done

# Check if input file is provided
if [[ -z "$input_file" ]]; then
    log_output "fail" "No input Bash script provided."
    log_output "info" "Use -h or --help for usage information."
    exit 1
fi

# Determine default output filename if not specified
if [[ -z "$output_file" ]]; then
    base_name="${input_file%.*}"
    if [[ "$base_name" == "$input_file" ]]; then
        output_file="${input_file}.exe"
    else
        output_file="$base_name"
    fi
fi

# Transpiler logic

# Create a temporary C source file
temp_c_file=$(mktemp /tmp/shave.XXXXXX.c)

# Generate C boilerplate
log_output "step" "Generating C Boilerplate"
generate_c_boilerplate "$temp_c_file"

# Parse Bash script and append generated C code
log_output "step" "Parsing Bash to C"
if ! parse_bash_to_c "$input_file" "$temp_c_file"; then
    log_output "fail" "Failed to parse Bash script. Exiting."
    rm -f "$temp_c_file"
    exit 1
fi

# Compile the generated C code to executable
log_output "step" "Compiling to Executable"
if ! compile_c_to_executable "$temp_c_file" "$output_file" "$keep_c_file"; then
    log_output "fail" "Failed to compile C code to executable. Exiting."
    exit 1
fi

log_output "step" "Finalizing Output"
log_output "done" "Conversion complete. Executable created at '$output_file'."
exit 0
