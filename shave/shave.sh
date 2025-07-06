#!/bin/bash

# Shave: A Bash-to-C Transpiler
# ===============================
# This script converts Bash scripts into C executables, enabling portability
# and performance improvements by compiling Bash logic into native code.

# CHANGELOG
# =========
# Version 1.0.0 - 2025-07-06 - First stable release with core functionality.
# Version 0.1.0 - 2025-07-05 - Initial setup of Shave transpiler.

# Script Metadata
# ===============
# Defines the name and version of the Shave script for consistent identification.
SHAVE_SCRIPT_NAME=$(basename "$0")
SHAVE_SCRIPT_VERSION="1.0.0"

# Display Help Information
# =========================
# Shows usage instructions and options for the Shave transpiler.
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

# Set Start Time
# ==============
# Records the start time of the script execution for performance tracking.
export SHAVE_START_TIME
SHAVE_START_TIME=$(date +%s%3N)

# Source Modular Components
# =========================
# Determines the script's directory to source modular components reliably.
SCRIPT_DIR=""
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Early Option Check
# ==================
# Checks for help or version options before initializing logging to avoid unnecessary logs.
input_file=""
debug_mode="false"
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
    elif [[ -z "$input_file" && "$arg" != -* ]]; then
        input_file="$arg"
    elif [[ "$arg" == "-d" || "$arg" == "--debug" ]]; then
        debug_mode="true"
    fi
done

# Initialize Logging
# ==================
# Sources shave-output.sh first to ensure logging functionality is available.
# shellcheck source=./shave-output.sh  # Essential for logging and output handling
# shellcheck disable=SC1091  # File path is dynamically determined at runtime
. "$SCRIPT_DIR/shave-output.sh"
log_output "init" "Initializing $SHAVE_SCRIPT_NAME $SHAVE_SCRIPT_VERSION"

# Script Timestamp Extraction
# ===========================
# Extracts the script's timestamp, handling differences between macOS and Linux systems.
script_location="$SCRIPT_DIR/shave.sh"
if stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location" >/dev/null 2>&1; then
    script_timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location")
else
    raw_timestamp=$(stat -c %y "$script_location" | cut -d. -f1)
    script_timestamp="$raw_timestamp $(date +%Z)"
fi
log_output "info" "Script Timestamp: $script_timestamp"

# Set Absolute Root Path
# ======================
# Determines the absolute path of the input file for consistent file handling.
if [[ -n "$input_file" ]]; then
    absolute_root_path="$(realpath "$input_file" 2>/dev/null || readlink -f "$input_file" 2>/dev/null)"
    if [[ "$debug_mode" == "true" && -n "$absolute_root_path" ]]; then
        log_output "info" "Absolute Root: $(dirname "$absolute_root_path")/"
    fi
    set_absolute_root "$absolute_root_path"
fi

log_output "step" "Sourcing Scripts"
# ======================
# Loads all necessary modular scripts for the transpiler's functionality.
# shellcheck source=./shave-boilerplate.sh  # Provides boilerplate C code generation
# shellcheck source=./shave-compiler.sh  # Handles compilation of C code
# shellcheck source=./shave-parser.sh  # Parses Bash scripts for conversion
# shellcheck source=./shave-hash.sh  # Manages hash generation for tracking
# shellcheck source=./shave-reader.sh  # Reads script content into arrays
# shellcheck source=./shave-combiner.sh  # Combines content and CST data
# shellcheck source=./shave-validate.sh  # Validates script syntax and status
# shellcheck source=./shave-process.sh  # Orchestrates the processing workflow
# shellcheck disable=SC1091  # File paths are dynamically determined at runtime
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

# Environment Validation
# ======================
# Checks for the presence of required tools and logs their versions.
log_output "step" "Validating Environment"
# Check for bash
if ! command -v bash >/dev/null 2>&1; then
    log_output "fail" "Bash is not installed. Please install Bash to run this script"
    exit 1
else
    bash_version=$(bash --version | head -1 | awk '{print $1 " " $2 " " $3 " " $4}')
    log_output "pass" "Bash is installed: $bash_version"
fi
# Check for gcc
if ! command -v gcc >/dev/null 2>&1; then
    log_output "fail" "GCC is not installed. Please install GCC to compile the generated C code"
    exit 1
else
    gcc_version=$(gcc --version | head -1 | awk '{print $1 " " $2 " " $3}')
    log_output "pass" "GCC is installed: $gcc_version"
fi
# Check for upx
if ! command -v upx >/dev/null 2>&1; then
    log_output "warn" "UPX is not installed. Compression step will be skipped"
else
    upx_version=$(upx --version | head -1 | awk '{print $1 " " $2}')
    log_output "pass" "UPX is installed: $upx_version"
fi
# Check for tree-sitter (assuming it's installed via npm)
if ! command -v tree-sitter >/dev/null 2>&1; then
    log_output "warn" "tree-sitter is not installed. Some parsing features may not work. Install via npm with 'npm install -g tree-sitter-cli'"
else
    tree_sitter_version=$(tree-sitter --version | head -1 | awk '{print $1 " " $2}')
    log_output "pass" "tree-sitter is installed: $tree_sitter_version"
fi
log_output "pass" "Environment validation complete"

# Output File Configuration
# =========================
# Initializes variables for output file naming and retention of C source files.
output_file=""
keep_c_file="false"


# Parse Command Line Options
# ==========================
# Processes command line arguments to configure the transpiler's behavior.
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

# Export Debug Mode
# =================
# Makes debug mode setting available to other sourced scripts.
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
# shellcheck disable=SC2034  # Variable kept for compatibility, appears unused to shellcheck
input_file_full_path=$(realpath "$input_file" 2>/dev/null || readlink -f "$input_file" 2>/dev/null)  # Unused but kept for compatibility

# Transpiler Logic
# ================
# Core logic for processing Bash scripts into C executables.

# Initial Processing
# ------------------
log_output "step" "Initial Processing for '$input_file'"
# Process the input script and any sourced dependencies, which will handle validation, FILE log line, and boilerplate generation
if ! process "$input_file" "$temp_c_file"; then
    log_output "fail" "Failed to process Bash script. Exiting"
    rm -f "$temp_c_file"
    exit 1
fi

# Populate Hash Table in C Source
# -------------------------------
# Adds hash table contents as comments in the generated C source file.
log_output "step" "Populating Hash Table Contents in C Source"
hash_table_content=$(populate_hash_table_comments)
if [ -z "$hash_table_content" ]; then
    log_output "warn" "No hash table contents to add. Hash table might be empty"
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

# Compile to Executable
# ---------------------
# Compiles the generated C code into a native executable.
log_output "step" "Compiling to Executable"
if ! compile_c_to_executable "$temp_c_file" "$output_file" "$keep_c_file"; then
    log_output "fail" "Failed to compile C code to executable. Exiting"
    exit 1
fi

# Finalize Output
# ---------------
# Cleans up temporary files and logs the completion of the process.
log_output "step" "Finalizing Output"
if [ "$keep_c_file" == "true" ]; then
    log_output "info" "Keeping generated C source file at '$temp_c_file'"
else
    log_output "info" "Removing generated C source file at '$temp_c_file'"
    rm -f "$temp_c_file"
fi
if [ "$DEBUG_MODE" == "true" ]; then
    log_output "info" "Debug mode enabled: Temporary files for CST and combined data have been logged during processing"
fi
log_output "done" "Conversion complete. Executable created at '$output_file'"
exit 0
