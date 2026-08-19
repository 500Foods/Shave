# shave_wc: reusable in-process GNU wc
#
# CHANGELOG
# 1.1.0 - 2026-08-18 - Build a shared library so gcov notes stay in the .so
# 1.0.3 - 2026-08-18 - Standalone or add_subdirectory library target

cmake_minimum_required(VERSION 3.16)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(shave_wc VERSION 1.0.3 LANGUAGES C)
    set(CMAKE_C_STANDARD 17)
    set(CMAKE_C_STANDARD_REQUIRED ON)
    set(CMAKE_C_EXTENSIONS OFF)
endif()

add_library(shave_wc SHARED shave_wc.c)
add_library(shave::wc ALIAS shave_wc)
set_target_properties(shave_wc PROPERTIES
    PUBLIC_HEADER shave_wc.h
    POSITION_INDEPENDENT_CODE ON
    OUTPUT_NAME shave_wc
)
target_include_directories(shave_wc PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
)

install(TARGETS shave_wc
    LIBRARY DESTINATION lib
    PUBLIC_HEADER DESTINATION include
)
