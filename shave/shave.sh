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
# shellcheck disable=SC1091
# Note: shellcheck may report SC1091 as the file paths are dynamically determined
for script in "$SCRIPT_DIR/shave-boilerplate.sh" "$SCRIPT_DIR/shave-compiler.sh" "$SCRIPT_DIR/shave-parser.sh" "$SCRIPT_DIR/shave-hash.sh"; do
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
if ! type parse_bash_to_c >/dev/null 2>&1; then
    log_output "fail" "Function parse_bash_to_c not found. Sourcing failed"
    exit 1
fi
if ! type compile_c_to_executable >/dev/null 2>&1; then
    log_output "fail" "Function compile_c_to_executable not found. Sourcing failed"
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

# Determine default output filename if not specified
if [[ -z "$output_file" ]]; then
    base_name="${input_file%.*}"
    if [[ "$base_name" == "$input_file" ]]; then
        output_file="${input_file}.exe"
    else
        output_file="$base_name"
    fi
fi

# Validate the input Bash script syntax using bash -n
log_output "step" "Validating source script syntax"
# Get file stats for input file
file_size=$(wc -c < "$input_file" | awk '{print $1}')
line_count=$(wc -l < "$input_file" | awk '{print $1}')
# Handle timestamp extraction for different systems (macOS vs Linux)
if stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$input_file" >/dev/null 2>&1; then
    source_timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$input_file")
else
    # Use date to format with timezone if possible, or append timezone manually
    raw_timestamp=$(stat -c %y "$input_file" | cut -d. -f1)
    source_timestamp="$raw_timestamp $(date +%Z)"
fi
current_timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
# Output file size and timestamp on separate lines
log_output "info" "$input_file is $(format_number "$file_size") bytes ($(format_number "$line_count") lines)"
log_output "info" "Source Timestamp: $current_timestamp"
if ! bash -n "$input_file"; then
    log_output "fail" "Source script syntax validation failed. Exiting"
    exit 1
fi
log_output "pass" "Source script syntax validated successfully"

# Generate and display hash for the input script after validation
SCRIPT_FILENAME="$input_file"
HASH_VALUE=$(hash "$SCRIPT_FILENAME" "source")
log_output "info" "Hash for script '$SCRIPT_FILENAME': $HASH_VALUE"
# Ensure the hash is stored in the table by calling the function explicitly
hash "$SCRIPT_FILENAME" "source" > /dev/null

# Parse the input script with tree-sitter if available
log_output "step" "Parsing Script"
if command -v tree-sitter >/dev/null 2>&1; then
    tree_sitter_output=$(tree-sitter parse "$input_file" 2> /tmp/shave-tree-sitter-error.log)
    tree_sitter_status=$?
if [ $tree_sitter_status -eq 0 ]; then
    parse_line_count=$(echo "$tree_sitter_output" | wc -l | awk '{print $1}')
    log_output "info" "tree-sitter parsed $input_file: $(format_number "$parse_line_count") statements"
    log_output "pass" "Concrete Syntax Tree (CST) generated"
else
        log_output "warn" "tree-sitter parsing failed. See errors in /tmp/shave-tree-sitter-error.log for details."
    fi
else
    log_output "warn" "tree-sitter is not installed. Skipping parsing step."
fi

# Transpiler logic

# Create a temporary C source file
temp_c_file=$(mktemp /tmp/shave.XXXXXX.c)

# Generate C boilerplate
log_output "step" "Generating C Boilerplate"
# Get fully qualified path for input file
input_file_full_path=$(realpath "$input_file" 2>/dev/null || readlink -f "$input_file" 2>/dev/null)
generate_c_boilerplate "$temp_c_file" "$input_file_full_path" "$input_file" "$file_size" "$line_count" "$source_timestamp" "$SHAVE_SCRIPT_NAME" "$SHAVE_SCRIPT_VERSION"

# Parse Bash script and append generated C code
log_output "step" "Parsing Bash to C"
log_output "file" "$input_file_full_path"
if ! parse_bash_to_c "$input_file" "$temp_c_file"; then
    log_output "fail" "Failed to parse Bash script. Exiting"
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
log_output "done" "Conversion complete. Executable created at '$output_file'"
exit 0
