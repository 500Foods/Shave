#!/bin/bash

# shave-hash.sh - Hashing utility for Shave project using FNV-1a algorithm

# Declare a global associative array to store hash-string pairs
declare -A HASH_TABLE

# Function to compute a 32-bit FNV-1a hash of a string
# Arguments:
#   $1 - The string to hash
# Returns:
#   The computed hash as a hexadecimal string
fnv1a_hash() {
    local string="$1"
    local hash=0x811c9dc5  # FNV offset basis for 32-bit
    local fnv_prime=0x01000193  # FNV prime for 32-bit
    local i char

    # Process each character in the string
    for ((i=0; i<${#string}; i++)); do
        char="${string:$i:1}"
        # XOR the hash with the ASCII value of the character
        hash=$((hash ^ $(printf '%d' "'$char")))
        # Multiply by the FNV prime
        hash=$((hash * fnv_prime))
        # Ensure 32-bit by masking with 0xFFFFFFFF
        hash=$((hash & 0xFFFFFFFF))
    done

    # Convert to hexadecimal, remove '0x' prefix, and ensure lowercase
    printf '%08x' "$hash" | tr '[:upper:]' '[:lower:]'
}

# Function to generate or retrieve a hash for a string
# If the string's hash exists, return it
# If not, compute a new hash, handle collisions with asterisk suffix
# Arguments:
#   $1 - The string to hash
#   $2 - The type of hash ("source", "variable", or "function") to prefix as "s_", "v_", or "f_"
#   $3 - The context to prefix to the hash (optional, with underscore separator)
# Returns:
#   The hash (existing or new) as a hexadecimal string with prefixes
hash() {
    local input="$1"
    local type="$2"
    local context="$3"
    local computed_hash new_key prefix

    # Determine prefix based on type
    case "$type" in
        "source") prefix="s_" ;;
        "variable") prefix="v_" ;;
        "function") prefix="f_" ;;
        *) prefix="" ;;
    esac

    # Add context to prefix if provided
    if [[ -n "$context" ]]; then
        prefix="${context}_${prefix}"
    fi

    # First, check if the input string already has a hash in the table
    for key in "${!HASH_TABLE[@]}"; do
        if [[ "${HASH_TABLE[$key]}" == "$input" ]]; then
            echo "$key"
            return
        fi
    done

    # Compute the initial hash
    computed_hash=$(fnv1a_hash "$input")
    new_key="${prefix}${computed_hash}"

    # Check for collision
    if [[ -n "${HASH_TABLE[$new_key]}" ]]; then
        # Collision detected, append asterisk and recompute until unique
        local suffix="*"
        while [[ -n "${HASH_TABLE[$new_key]}" ]]; do
            computed_hash=$(fnv1a_hash "${input}${suffix}")
            new_key="${prefix}${computed_hash}"
            suffix="${suffix}*"
        done
    fi

    # Store the new hash-string pair in the table
    HASH_TABLE["$new_key"]="$input"
    echo "$new_key"
}

# Function to list the contents of the hash table
# Outputs each hash and its corresponding string
list_hash_table() {
    echo "Hash Table Contents:"
    echo "--------------------"
    for hash in "${!HASH_TABLE[@]}"; do
        printf "Hash: %s  String: %s\n" "$hash" "${HASH_TABLE[$hash]}"
    done
    echo "--------------------"
}

# Function to format hash table contents as C comments
# Outputs the hash table contents in the format "// hash: string"
populate_hash_table_comments() {
    for hash in "${!HASH_TABLE[@]}"; do
        echo "// $hash: ${HASH_TABLE[$hash]}"
    done
}

# Main script logic
# Generate a hash for the script filename being processed
# This is intended to be called from within the Shave workflow
# Expects SCRIPT_FILENAME to be set or passed as an argument
# This block ensures the hash is generated and stored even if called indirectly
if [[ -n "$SCRIPT_FILENAME" ]]; then
    HASH_VALUE=$(hash "$SCRIPT_FILENAME" "source")
    echo "INFO   Hash for script '$SCRIPT_FILENAME': $HASH_VALUE"
fi
