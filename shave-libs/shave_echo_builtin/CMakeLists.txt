# shave_echo_builtin: reusable in-process Bash echo
#
# CHANGELOG
# 1.1.0 - 2026-08-18 - Build a shared library so gcov notes stay in the .so
# 1.0.3 - 2026-08-18 - Folder renamed to shave_echo_builtin
# 1.0.0 - 2026-08-18 - Standalone or add_subdirectory library target

cmake_minimum_required(VERSION 3.16)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(shave_echo_builtin VERSION 1.0.1 LANGUAGES C)
    set(CMAKE_C_STANDARD 17)
    set(CMAKE_C_STANDARD_REQUIRED ON)
    set(CMAKE_C_EXTENSIONS OFF)
endif()

add_library(shave_echo_builtin SHARED shave_echo_builtin.c)
add_library(shave::echo_builtin ALIAS shave_echo_builtin)
set_target_properties(shave_echo_builtin PROPERTIES
    PUBLIC_HEADER shave_echo_builtin.h
    POSITION_INDEPENDENT_CODE ON
    OUTPUT_NAME shave_echo_builtin
)
target_include_directories(shave_echo_builtin PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
)

install(TARGETS shave_echo_builtin
    LIBRARY DESTINATION lib
    PUBLIC_HEADER DESTINATION include
)
