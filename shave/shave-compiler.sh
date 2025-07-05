#!/bin/bash
# Shave Compiler: Handles compilation of generated C code to executable.

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh
. "$SCRIPT_DIR/shave-output.sh"

# Function to compile C source to executable
compile_c_to_executable() {
    local c_source_file="$1"
    local output_executable="$2"
    local keep_c_file="$3"
    
    # Check if gcc is installed
    if ! command -v gcc >/dev/null 2>&1; then
        log_output "fail" "GCC is not installed. Please install GCC to compile the generated C code."
        return 1
    fi
    
    # Compile with C17 standard and GNU source for portability
    log_output "info" "Compiling $c_source_file to $output_executable..."
    gcc -std=c17 -D_GNU_SOURCE -o "$output_executable" "$c_source_file" 2> /tmp/shave-compile-error.log
    local compile_status=$?
    if [ $compile_status -eq 0 ]; then
        # Set executable permissions
        chmod +x "$output_executable"
        log_output "pass" "Successfully compiled to $output_executable"
        # Clean up temporary C source file on success unless keep is specified
        if [ "$keep_c_file" != "true" ]; then
            rm -f "$c_source_file"
        else
            log_output "info" "Keeping generated C source file at $c_source_file"
        fi
        return 0
    else
        log_output "fail" "Compilation failed. See errors in /tmp/shave-compile-error.log for details."
        log_output "info" "Temporary C source file retained at $c_source_file for debugging."
        return 1
    fi
}
