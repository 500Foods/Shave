#!/bin/bash
# Shave Compiler: Handles compilation of generated C code to executable.
#
# CHANGELOG
# 1.3.0 - 2026-08-18 - Link shared shave-libs and embed rpath
# 1.2.2 - 2026-08-18 - Fingerprint the shave/shave product CLI
# 1.2.1 - 2026-08-18 - Safe to source under set -u via output defaults
# 1.2.0 - 2026-08-18 - Link shave-libs, SHAVE_* overrides, skip unchanged builds
# 1.1.0 - 2026-08-18 - Compress generated executables with UPX -9
# 1.0.0 - 2025-07-06 - Initial compiler module

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh  # Essential for logging and output handling
# shellcheck disable=SC1091  # File path is dynamically determined at runtime
. "$SCRIPT_DIR/shave-output.sh"

shave_detect_root() {
    local detected=""
    if [[ -n "${SHAVE_ROOT:-}" && -d "${SHAVE_ROOT}" ]]; then
        printf '%s\n' "${SHAVE_ROOT}"
        return 0
    fi
    if [[ -d "${SCRIPT_DIR}/../shave-libs" ]]; then
        detected="$(cd "${SCRIPT_DIR}/.." && pwd)"
        printf '%s\n' "${detected}"
        return 0
    fi
    if [[ -d "${SCRIPT_DIR}/shave-libs" ]]; then
        printf '%s\n' "${SCRIPT_DIR}"
        return 0
    fi
    printf '\n'
}

shave_split_flags() {
    local value="$1"
    local -a tokens=()
    if [[ -z "${value}" ]]; then
        return 0
    fi
    read -r -a tokens <<< "${value}"
    if [[ "${#tokens[@]}" -gt 0 ]]; then
        printf '%s\n' "${tokens[@]}"
    fi
}

shave_hash_text() {
    local text="$1"
    if command -v md5sum >/dev/null 2>&1; then
        printf '%s' "${text}" | md5sum | awk '{print $1}'
        return 0
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "${text}" | sha256sum | awk '{print $1}'
        return 0
    fi
    printf '%s' "${text}" | cksum | awk '{print $1}'
}

shave_hash_files() {
    if [[ "$#" -eq 0 ]]; then
        shave_hash_text ""
        return 0
    fi
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$@" | sort | md5sum | awk '{print $1}'
        return 0
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$@" | sort | sha256sum | awk '{print $1}'
        return 0
    fi
    cksum "$@" | sort | cksum | awk '{print $1}'
}

shave_collect_libs() {
    SHAVE_INCLUDE_FLAGS=()
    SHAVE_LIB_SOURCES=()
    SHAVE_LIB_SHARED=()
    SHAVE_LIB_ARCHIVES=()
    SHAVE_LIB_HASH_FILES=()
    SHAVE_LIB_RPATH=""

    local root="${SHAVE_ROOT:-}"
    local libdir="${SHAVE_LIBDIR:-}"
    local dir=""
    local c_file=""
    local so_file=""
    local a_file=""
    local name=""
    local saved_nullglob=""

    if [[ -n "${SHAVE_INCLUDEDIR:-}" ]]; then
        SHAVE_INCLUDE_FLAGS+=(-I "${SHAVE_INCLUDEDIR}")
    fi
    if [[ -z "${root}" || ! -d "${root}/shave-libs" ]]; then
        return 0
    fi
    if [[ -z "${libdir}" ]]; then
        libdir="${root}/build"
    fi

    saved_nullglob="$(shopt -p nullglob)"
    shopt -s nullglob
    for dir in "${root}/shave-libs"/*/; do
        SHAVE_INCLUDE_FLAGS+=(-I "${dir%/}")
        for c_file in "${dir}"shave_*.c; do
            [[ -f "${c_file}" ]] || continue
            name="$(basename "${c_file}" .c)"
            so_file="${libdir}/lib${name}.so"
            a_file="${libdir}/lib${name}.a"
            SHAVE_LIB_HASH_FILES+=("${c_file}")
            if [[ -f "${dir}${name}.h" ]]; then
                SHAVE_LIB_HASH_FILES+=("${dir}${name}.h")
            fi
            if [[ -f "${so_file}" ]]; then
                SHAVE_LIB_SHARED+=("${so_file}")
                SHAVE_LIB_HASH_FILES+=("${so_file}")
                SHAVE_LIB_RPATH="${libdir}"
            elif [[ -f "${a_file}" ]]; then
                SHAVE_LIB_ARCHIVES+=("${a_file}")
                SHAVE_LIB_HASH_FILES+=("${a_file}")
            else
                SHAVE_LIB_SOURCES+=("${c_file}")
            fi
        done
    done
    eval "${saved_nullglob}"
}

shave_compiler_name() {
    if [[ -n "${SHAVE_CC:-}" ]]; then
        printf '%s\n' "${SHAVE_CC}"
        return 0
    fi
    printf '%s\n' "gcc"
}

shave_build_stamp_path() {
    local output_executable="$1"
    printf '%s.shave\n' "${output_executable}"
}

shave_stamp_field() {
    local stamp="$1"
    local field="$2"
    sed -n "s/^${field}=//p" "${stamp}" | head -n 1
}

shave_tool_fingerprint() {
    local c_source_file="$1"
    local output_executable="$2"
    local cc=""
    local extra_cflags=""
    local extra_ldflags=""
    local -a hash_files=()
    local recipe=""
    local file=""

    cc="$(shave_compiler_name)"
    extra_cflags="${SHAVE_GCC:-} ${SHAVE_CFLAGS:-}"
    extra_ldflags="${SHAVE_LDFLAGS:-}"
    shave_collect_libs

    if [[ -f "${SCRIPT_DIR}/shave" ]]; then
        hash_files+=("${SCRIPT_DIR}/shave")
    fi
    if [[ -f "${SCRIPT_DIR}/shave.sh" ]]; then
        hash_files+=("${SCRIPT_DIR}/shave.sh")
    fi
    for file in "${SCRIPT_DIR}"/shave-*.sh; do
        [[ -f "${file}" ]] || continue
        hash_files+=("${file}")
    done
    if [[ "${#SHAVE_LIB_HASH_FILES[@]}" -gt 0 ]]; then
        hash_files+=("${SHAVE_LIB_HASH_FILES[@]}")
    fi

    recipe="$(printf '%s\n' \
        "cc=${cc}" \
        "cflags=${extra_cflags}" \
        "ldflags=${extra_ldflags}" \
        "includes=${SHAVE_INCLUDE_FLAGS[*]-}" \
        "sources=${SHAVE_LIB_SOURCES[*]-}" \
        "shared=${SHAVE_LIB_SHARED[*]-}" \
        "archives=${SHAVE_LIB_ARCHIVES[*]-}" \
        "c=${c_source_file}" \
        "bin=${output_executable}" \
        "upx=${SHAVE_UPX--9}")"
    printf '%s\n' "$(shave_hash_files "${hash_files[@]}") $(shave_hash_text "${recipe}")"
}

shave_write_build_stamp() {
    local input_file="$1"
    local c_source_file="$2"
    local output_executable="$3"
    local stamp=""

    stamp="$(shave_build_stamp_path "${output_executable}")"
    {
        printf 'input=%s\n' "$(shave_hash_files "${input_file}")"
        printf 'tool=%s\n' "$(shave_tool_fingerprint "${c_source_file}" "${output_executable}")"
        if [[ -f "${c_source_file}" ]]; then
            printf 'c=%s\n' "$(shave_hash_files "${c_source_file}")"
        fi
    } > "${stamp}"
}

# Function to compile C source to executable
compile_c_to_executable() {
    local c_source_file="$1"
    local output_executable="$2"
    local cc=""
    local compile_status=0
    local -a extra_cflags=()
    local -a extra_ldflags=()
    local -a compile_cmd=()
    local -a upx_flags=()
    local rpath_flag=""
    local output_dir=""
    local flag=""
    local size_before=""
    local size_after=""
    local reduction_percent=""
    local upx_status=0

    cc="$(shave_compiler_name)"
    if ! command -v "${cc}" >/dev/null 2>&1; then
        log_output "fail" "Compiler ${cc} is not installed"
        return 1
    fi

    output_dir="$(dirname "${output_executable}")"
    if [[ -n "${output_dir}" && "${output_dir}" != "." && ! -d "${output_dir}" ]]; then
        mkdir -p "${output_dir}"
    fi

    while IFS= read -r flag; do
        extra_cflags+=("${flag}")
    done < <(shave_split_flags "${SHAVE_GCC:-}")
    while IFS= read -r flag; do
        extra_cflags+=("${flag}")
    done < <(shave_split_flags "${SHAVE_CFLAGS:-}")
    while IFS= read -r flag; do
        extra_ldflags+=("${flag}")
    done < <(shave_split_flags "${SHAVE_LDFLAGS:-}")
    shave_collect_libs

    compile_cmd=(
        "${cc}"
        -std=c17
        -D_GNU_SOURCE
        -O2
        -s
    )
    if [[ "${#extra_cflags[@]}" -gt 0 ]]; then
        compile_cmd+=("${extra_cflags[@]}")
    fi
    if [[ "${#SHAVE_INCLUDE_FLAGS[@]}" -gt 0 ]]; then
        compile_cmd+=("${SHAVE_INCLUDE_FLAGS[@]}")
    fi
    compile_cmd+=(-o "${output_executable}" "${c_source_file}")
    if [[ "${#SHAVE_LIB_SOURCES[@]}" -gt 0 ]]; then
        compile_cmd+=("${SHAVE_LIB_SOURCES[@]}")
    fi
    if [[ "${#SHAVE_LIB_SHARED[@]}" -gt 0 ]]; then
        compile_cmd+=("${SHAVE_LIB_SHARED[@]}")
    fi
    if [[ -n "${SHAVE_LIB_RPATH}" ]]; then
        rpath_flag="-Wl,-rpath,${SHAVE_LIB_RPATH}"
        compile_cmd+=("${rpath_flag}")
    fi
    if [[ "${#SHAVE_LIB_ARCHIVES[@]}" -gt 0 ]]; then
        compile_cmd+=("${SHAVE_LIB_ARCHIVES[@]}")
    fi
    if [[ "${#extra_ldflags[@]}" -gt 0 ]]; then
        compile_cmd+=("${extra_ldflags[@]}")
    fi

    log_output "info" "Compiling ${c_source_file} to ${output_executable}"
    "${compile_cmd[@]}" 2> /tmp/shave-compile-error.log
    compile_status=$?
    if [ $compile_status -eq 0 ]; then
        chmod +x "${output_executable}"
        log_output "pass" "Successfully compiled to ${output_executable}"

        if [[ "${SHAVE_UPX:-}" == "0" || "${SHAVE_UPX:-}" == "off" || "${SHAVE_UPX:-}" == "false" ]]; then
            log_output "info" "UPX skipped by SHAVE_UPX"
        elif command -v upx >/dev/null 2>&1; then
            log_output "step" "Compressing with UPX"
            size_before=$(wc -c < "${output_executable}" | awk '{print $1}')
            while IFS= read -r flag; do
                upx_flags+=("${flag}")
            done < <(shave_split_flags "${SHAVE_UPX:--9}")
            upx "${upx_flags[@]}" "${output_executable}" >/dev/null 2> /tmp/shave-upx-error.log || upx_status=$?
            if [ $upx_status -eq 0 ]; then
                size_after=$(wc -c < "${output_executable}" | awk '{print $1}')
                if [ "${size_before}" -gt 0 ]; then
                    reduction_percent=$(awk "BEGIN {printf \"%.1f\", ((${size_before} - ${size_after}) * 100) / ${size_before}}")
                else
                    reduction_percent="0.0"
                fi
                log_output "info" "UPX compression: Before $(format_number "${size_before}") bytes, After $(format_number "${size_after}") bytes, Reduction ${reduction_percent}%"
                log_output "pass" "Successfully compressed ${output_executable} with UPX"
            else
                log_output "warn" "UPX compression failed. See errors in /tmp/shave-upx-error.log for details"
            fi
        else
            log_output "warn" "UPX is not installed. Skipping compression step"
        fi
        return 0
    else
        log_output "fail" "Compilation failed. See errors in /tmp/shave-compile-error.log for details"
        log_output "info" "C source file retained at ${c_source_file} for debugging"
        return 1
    fi
}
