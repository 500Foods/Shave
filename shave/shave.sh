#!/bin/bash
# Shave: A Bash-to-C transpiler for converting Bash scripts to C executables.

# CHANGELOG
# Version 0.1.0 - 2025-07-05 - Initial setup of Shave transpiler.

# Script metadata
SHAVE_SCRIPT_NAME=$(basename "$0")
SHAVE_SCRIPT_VERSION="0.1.0"

# Display help information
show_help() {
    echo "Usage: $SHAVE_SCRIPT_NAME [options] <input_bash_script>"
    echo "Convert a Bash script to a C executable"
    echo ""
    echo "Options:"
    echo "  -h, --help            Display this help message and exit"
    echo "  -v, --version         Display the version of this script and exit"
    echo "  -o, --output <file>   Specify the output C executable name"
    echo "                        Defaults to input script name without extension"
    echo "                        or appends '.exe' if no extension exists"
    echo "  -k, --keep            Keep the generated C source file after compilation"
    echo "  -d, --debug           Enable debug mode: keep C source file and generate/log temporary files for CST and combined data"
    echo ""
    echo "Example:"
    echo "  $SHAVE_SCRIPT_NAME myscript.sh"
    echo "  $SHAVE_SCRIPT_NAME -o myprogram myscript.sh"
    exit 0
}

# Set the start time at the very beginning of the script
export SHAVE_START_TIME
SHAVE_START_TIME=$(date +%s%3N)
# Source modular components using the script's directory
SCRIPT_DIR=""
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Check for --help or --version option early to bypass logging
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "$SHAVE_SCRIPT_NAME $SHAVE_SCRIPT_VERSION"
        show_help
    elif [[ "$arg" == "-v" || "$arg" == "--version" ]]; then
        # Handle script timestamp extraction for different systems (macOS vs Linux)
        script_location="$SCRIPT_DIR/shave.sh"
        if stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location" >/dev/null 2>&1; then
            script_timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location")
        else
            raw_timestamp=$(stat -c %y "$script_location" | cut -d. -f1)
            script_timestamp="$raw_timestamp $(date +%Z)"
        fi
        echo "$SHAVE_SCRIPT_NAME $SHAVE_SCRIPT_VERSION"
        echo "Script Timestamp: $script_timestamp"
        exit 0
    fi
done
# Source shave-output.sh first to ensure log_output is available
# shellcheck source=./shave-output.sh
# shellcheck disable=SC1091
# Note: shellcheck may report SC1091 as the file path is dynamically determined
. "$SCRIPT_DIR/shave-output.sh"
log_output "init" "Initializing $SHAVE_SCRIPT_NAME $SHAVE_SCRIPT_VERSION"
# Handle script timestamp extraction for different systems (macOS vs Linux)
script_location="$SCRIPT_DIR/shave.sh"
if stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location" >/dev/null 2>&1; then
    script_timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location")
else
    raw_timestamp=$(stat -c %y "$script_location" | cut -d. -f1)
    script_timestamp="$raw_timestamp $(date +%Z)"
fi
log_output "info" "Script Timestamp: $script_timestamp"
log_output "step" "Sourcing scripts"
# shellcheck source=./shave-boilerplate.sh
# shellcheck source=./shave-compiler.sh
# shellcheck source=./shave-parser.sh
# shellcheck source=./shave-hash.sh
# shellcheck source=./shave-reader.sh
# shellcheck source=./shave-combiner.sh
# shellcheck source=./shave-validate.sh
# shellcheck source=./shave-process.sh
# shellcheck disable=SC1091
# Note: shellcheck may report SC1091 as the file paths are dynamically determined
for script in "$SCRIPT_DIR/shave-boilerplate.sh" "$SCRIPT_DIR/shave-compiler.sh" "$SCRIPT_DIR/shave-parser.sh" "$SCRIPT_DIR/shave-hash.sh" "$SCRIPT_DIR/shave-reader.sh" "$SCRIPT_DIR/shave-combiner.sh" "$SCRIPT_DIR/shave-validate.sh" "$SCRIPT_DIR/shave-process.sh"; do
    if [ -f "$script" ]; then
        log_output "info" "Sourcing $script"
        . "$script"
    else
        log_output "fail" "Script $script not found"
        exit 1
    fi
done

# Check if functions are available
if ! type generate_c_boilerplate >/dev/null 2>&1; then
    log_output "fail" "Function generate_c_boilerplate not found. Sourcing failed"
    exit 1
fi
if ! type compile_c_to_executable >/dev/null 2>&1; then
    log_output "fail" "Function compile_c_to_executable not found. Sourcing failed"
    exit 1
fi
if ! type process >/dev/null 2>&1; then
    log_output "fail" "Function process not found. Sourcing failed"
    exit 1
fi
if ! type validate_script >/dev/null 2>&1; then
    log_output "fail" "Function validate_script not found. Sourcing failed"
    exit 1
fi
if ! type read_script_content >/dev/null 2>&1; then
    log_output "fail" "Function read_script_content not found. Sourcing failed"
    exit 1
fi
if ! type generate_cst >/dev/null 2>&1; then
    log_output "fail" "Function generate_cst not found. Sourcing failed"
    exit 1
fi
if ! type combine_content_cst >/dev/null 2>&1; then
    log_output "fail" "Function combine_content_cst not found. Sourcing failed"
    exit 1
fi
log_output "pass" "All functions sourced successfully"

# Validate environment for required tools
log_output "step" "Validating environment"
# Check for bash
if ! command -v bash >/dev/null 2>&1; then
    log_output "fail" "Bash is not installed. Please install Bash to run this script."
    exit 1
else
    bash_version=$(bash --version | head -1 | awk '{print $1 " " $2 " " $3 " " $4}')
    log_output "pass" "Bash is installed: $bash_version"
fi
# Check for gcc
if ! command -v gcc >/dev/null 2>&1; then
    log_output "fail" "GCC is not installed. Please install GCC to compile the generated C code."
    exit 1
else
    gcc_version=$(gcc --version | head -1 | awk '{print $1 " " $2 " " $3}')
    log_output "pass" "GCC is installed: $gcc_version"
fi
# Check for upx
if ! command -v upx >/dev/null 2>&1; then
    log_output "warn" "UPX is not installed. Compression step will be skipped."
else
    upx_version=$(upx --version | head -1 | awk '{print $1 " " $2}')
    log_output "pass" "UPX is installed: $upx_version"
fi
# Check for tree-sitter (assuming it's installed via npm)
if ! command -v tree-sitter >/dev/null 2>&1; then
    log_output "warn" "tree-sitter is not installed. Some parsing features may not work. Install via npm with 'npm install -g tree-sitter-cli'."
else
    tree_sitter_version=$(tree-sitter --version | head -1 | awk '{print $1 " " $2}')
    log_output "pass" "tree-sitter is installed: $tree_sitter_version"
fi
log_output "pass" "Environment validation complete"

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
                log_output "fail" "Output file name not specified"
                exit 1
            fi
            ;;
        -k|--keep)
            keep_c_file="true"
            shift
            ;;
        -d|--debug)
            keep_c_file="true"
            debug_mode="true"
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
    log_output "fail" "No input Bash script provided"
    log_output "info" "Use -h or --help for usage information"
    exit 1
fi

# Export debug mode variable for use in other scripts
export DEBUG_MODE="${debug_mode:-false}"

# Determine default output filename if not specified
if [[ -z "$output_file" ]]; then
    base_name="${input_file%.*}"
    if [[ "$base_name" == "$input_file" ]]; then
        output_file="${input_file}.exe"
    else
        output_file="$base_name"
    fi
fi

# Create a temporary C source file
temp_c_file=$(mktemp /tmp/shave.XXXXXX.c)
# Get fully qualified path for input file
input_file_full_path=$(realpath "$input_file" 2>/dev/null || readlink -f "$input_file" 2>/dev/null)

# Transpiler logic

# Emit initial processing step log
log_output "step" "Initial processing for '$input_file'"
# Process the input script and any sourced dependencies, which will handle validation, FILE log line, and boilerplate generation
if ! process "$input_file" "$temp_c_file"; then
    log_output "fail" "Failed to process Bash script. Exiting"
    rm -f "$temp_c_file"
    exit 1
fi

# Populate hash table contents as comments in the C source file
log_output "step" "Populating hash table contents in C source"
hash_table_content=$(populate_hash_table_comments)
if [ -z "$hash_table_content" ]; then
    log_output "warn" "No hash table contents to add. Hash table might be empty."
else
    # Create a temporary file with the content to insert
    temp_content_file=$(mktemp /tmp/shave-content.XXXXXX)
    echo "//" > "$temp_content_file"
    echo "$hash_table_content" >> "$temp_content_file"
    echo "//" >> "$temp_content_file"
    # Use sed to insert the content from the temporary file after "Hash Table Start"
    sed -i "/\/\/ Hash Table Start/r $temp_content_file" "$temp_c_file"
    rm -f "$temp_content_file"
    log_output "pass" "Hash table contents added to C source"
fi

# Compile the generated C code to executable
log_output "step" "Compiling to Executable"
if ! compile_c_to_executable "$temp_c_file" "$output_file" "$keep_c_file"; then
    log_output "fail" "Failed to compile C code to executable. Exiting"
    exit 1
fi

log_output "step" "Finalizing Output"
if [ "$keep_c_file" == "true" ]; then
    log_output "info" "Keeping generated C source file at '$temp_c_file'"
else
    log_output "info" "Removing generated C source file at '$temp_c_file'"
    rm -f "$temp_c_file"
fi
if [ "$DEBUG_MODE" == "true" ]; then
    log_output "info" "Debug mode enabled: Temporary files for CST and combined data have been logged during processing."
fi
log_output "done" "Conversion complete. Executable created at '$output_file'"
exit 0
