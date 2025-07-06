#!/bin/bash
# Shave Compiler: Handles compilation of generated C code to executable.

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh
# shellcheck disable=SC1091
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
    
    # Compile with C17 standard, GNU source for portability, and optimization flags
    log_output "info" "Compiling $c_source_file to $output_executable with optimization..."
    gcc -std=c17 -D_GNU_SOURCE -O2 -s -o "$output_executable" "$c_source_file" 2> /tmp/shave-compile-error.log
    local compile_status=$?
    if [ $compile_status -eq 0 ]; then
        # Set executable permissions
        chmod +x "$output_executable"
        log_output "pass" "Successfully compiled to $output_executable"
        
        # Check if upx is installed for compression
        if command -v upx >/dev/null 2>&1; then
            log_output "step" "Compressing with UPX"
            # Get size before compression
            local size_before
            size_before=$(wc -c < "$output_executable" | awk '{print $1}')
            # Run UPX and capture output to extract reduction percentage
            local upx_output
            # shellcheck disable=SC2034
            upx_output=$(upx --best "$output_executable" 2> /tmp/shave-upx-error.log)  # Reserved for future use
            local upx_status=$?
            if [ $upx_status -eq 0 ]; then
                # Get size after compression
                local size_after
                size_after=$(wc -c < "$output_executable" | awk '{print $1}')
                # Calculate reduction percentage
                local reduction_percent
                if [ "$size_before" -gt 0 ]; then
                    reduction_percent=$(awk "BEGIN {printf \"%.1f\", (($size_before - $size_after) * 100) / $size_before}")
                else
                    reduction_percent="0.0"
                fi
                log_output "info" "UPX compression: Before $(format_number "$size_before") bytes, After $(format_number "$size_after") bytes, Reduction $reduction_percent%"
                log_output "pass" "Successfully compressed $output_executable with UPX"
            else
                log_output "warn" "UPX compression failed. See errors in /tmp/shave-upx-error.log for details."
            fi
        else
            log_output "warn" "UPX is not installed. Skipping compression step."
        fi
        
        # Clean up temporary C source file on success unless keep is specified
        if [ "$keep_c_file" != "true" ]; then
            rm -f "$c_source_file"
        fi
        return 0
    else
        log_output "fail" "Compilation failed. See errors in /tmp/shave-compile-error.log for details."
        log_output "info" "Temporary C source file retained at $c_source_file for debugging."
        return 1
    fi
}
