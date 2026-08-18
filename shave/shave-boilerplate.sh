#!/bin/bash
# Shave Boilerplate: Generates the basic C code structure for the transpiler output.
#
# CHANGELOG
# 1.0.3 - 2026-08-18 - Include shave_wc
# 1.2.0 - 2026-08-18 - Include printf, locale, TZ, and loop variable helpers
# 1.1.0 - 2026-08-18 - Include echo builtin and status for generated mains
# 1.0.0 - Initial boilerplate

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh  # Essential for logging and output handling
# shellcheck disable=SC1091  # File path is dynamically determined at runtime
. "$SCRIPT_DIR/shave-output.sh"

# Function to generate C boilerplate code
generate_c_boilerplate() {
    local output_file="$1"
    local source_file="$2"
    # shellcheck disable=SC2034  # Variable kept for compatibility, appears unused to shellcheck
    local source_path="$3"  # Reserved for future use
    local source_size_bytes="$4"
    local source_lines="$5"
    local source_timestamp="$6"
    local script_name="$7"
    local script_version="$8"
    local generation_timestamp
    generation_timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    local script_location
    script_location="$SCRIPT_DIR/shave"
    # Handle script timestamp extraction for different systems (macOS vs Linux)
    local script_timestamp
    local raw_timestamp
    if stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location" >/dev/null 2>&1; then
        script_timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location")
    else
        raw_timestamp=$(stat -c %y "$script_location" | cut -d. -f1)
        script_timestamp="$raw_timestamp $(date +%Z)"
    fi
    # Format numbers with thousands separators
    local formatted_size_bytes
    local formatted_lines
    formatted_size_bytes=$(format_number "$source_size_bytes")
    formatted_lines=$(format_number "$source_lines")
    cat << EOF > "$output_file"
// -----------------------------------------------------------------------------
// Shave Transpiler Output
// Script Name: $script_name
// Script Version: $script_version
// Script Location: $script_location
// Script Timestamp: $script_timestamp
// Generation Timestamp: $generation_timestamp
// Source File: $source_file
// Source Size: $formatted_size_bytes bytes, $formatted_lines lines
// Source Timestamp: $source_timestamp
// -----------------------------------------------------------------------------

#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "shave_echo_builtin.h"
#include "shave_printf_builtin.h"
#include "shave_wc.h"

#define SHAVE_EXPAND_MAX 4096
#define SHAVE_VAR_MAX 32

struct shave_var {
    char name[64];
    char value[SHAVE_EXPAND_MAX];
};

static struct shave_var shave_vars[SHAVE_VAR_MAX];
static int shave_var_n;

static const char *shave_get_var(const char *name)
{
    int i;
    const char *env;

    if (name == NULL) {
        return "";
    }
    for (i = 0; i < shave_var_n; i++) {
        if (strcmp(shave_vars[i].name, name) == 0) {
            return shave_vars[i].value;
        }
    }
    env = getenv(name);
    if (env != NULL) {
        return env;
    }
    return "";
}

static void shave_set_var(const char *name, const char *value)
{
    int i;

    if (name == NULL) {
        return;
    }
    if (value == NULL) {
        value = "";
    }
    for (i = 0; i < shave_var_n; i++) {
        if (strcmp(shave_vars[i].name, name) == 0) {
            (void)snprintf(shave_vars[i].value, sizeof(shave_vars[i].value), "%s", value);
            return;
        }
    }
    if (shave_var_n >= SHAVE_VAR_MAX) {
        return;
    }
    (void)snprintf(shave_vars[shave_var_n].name, sizeof(shave_vars[shave_var_n].name), "%s", name);
    (void)snprintf(shave_vars[shave_var_n].value, sizeof(shave_vars[shave_var_n].value), "%s", value);
    shave_var_n++;
}

static void shave_buf_add(char *buf, size_t buflen, const char *text)
{
    size_t used;

    if (buf == NULL || buflen == 0) {
        return;
    }
    if (text == NULL) {
        text = "";
    }
    used = strlen(buf);
    if (used + 1 >= buflen) {
        return;
    }
    (void)strncat(buf, text, buflen - used - 1);
}

// Hash Table Start
// Hash Table End

int main(int argc, char *argv[]) {
    int status = 0;
    (void)argc;
    (void)argv;
    (void)setlocale(LC_ALL, "");
    // Script start - Additional generated code will be inserted here
    // Script end - Transpiled code stops here
    return status == 0 ? 0 : 1;
}
EOF
    log_output "info" "Generated C boilerplate in $output_file"
}
