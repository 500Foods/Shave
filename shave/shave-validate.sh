#!/bin/bash
# Shave Validate: Validates Bash scripts for syntax and checks if already processed.

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh
# shellcheck disable=SC1091
# Note: shellcheck may report SC1091 as the file path is dynamically determined
. "$SCRIPT_DIR/shave-output.sh"

# Function to validate a script for syntax and check if already processed
validate_script() {
    local input_script="$1"
    local stats_array_name="$2"  # Name of the associative array to store file statistics
    
    # Check if input file exists
    if [[ ! -f "$input_script" ]]; then
        log_output "fail" "Input script '$input_script' not found."
        return 1
    fi
    
    # Convert to absolute path
    local absolute_path
    absolute_path=$(realpath "$input_script" 2>/dev/null || readlink -f "$input_script" 2>/dev/null)
    if [[ -z "$absolute_path" ]]; then
        log_output "fail" "Could not determine absolute path for '$input_script'."
        return 1
    fi
    
    # Check if the script is already in the hash table
    for key in "${!HASH_TABLE[@]}"; do
        if [[ "${HASH_TABLE[$key]}" == "$absolute_path" ]]; then
            log_output "info" "Script '$input_script' already processed (hash: $key). Skipping."
            return 1
        fi
    done
    
    # Gather file statistics
    local size=$(wc -c < "$input_script" | awk '{print $1}')
    local lines=$(wc -l < "$input_script" | awk '{print $1}')
    local timestamp
    if stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$input_script" >/dev/null 2>&1; then
        timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$input_script")
    else
        local raw_timestamp=$(stat -c %y "$input_script" | cut -d. -f1)
        timestamp="$raw_timestamp $(date +%Z)"
    fi
    log_output "info" "$input_script is $(format_number "$size") bytes ($(format_number "$lines") lines)"
    log_output "info" "Source Timestamp: $timestamp"
    
    # Validate syntax using bash -n
    if ! bash -n "$input_script"; then
        log_output "fail" "Syntax validation failed for '$input_script'."
        return 1
    fi
    
    # Generate and store hash for the absolute path
    local hash_value
    hash_value=$(hash "$absolute_path" "source")
    HASH_TABLE["$hash_value"]="$absolute_path"
    log_output "info" "Validated script '$input_script' with hash '$hash_value'."
    log_output "info" "Hash for script '$input_script': $hash_value"
    
    # Populate the provided associative array with statistics
    declare -g -A "$stats_array_name"
    declare -g "${stats_array_name}[size]=$size"
    declare -g "${stats_array_name}[lines]=$lines"
    declare -g "${stats_array_name}[timestamp]=$timestamp"
    declare -g "${stats_array_name}[hash]=$hash_value"
    return 0
}
