cmake_minimum_required(VERSION 3.16)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" SHAVE_VERSION_RAW)
string(STRIP "${SHAVE_VERSION_RAW}" SHAVE_VERSION)

project(Shave VERSION ${SHAVE_VERSION} LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

option(SHAVE_BUILD_TESTS "Build Unity tests" ON)

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/shave/version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/include/shave_version.h"
    @ONLY
)

add_library(shave_version_info STATIC shave/version_info.c)
target_include_directories(shave_version_info PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/shave")

add_executable(shave-version shave/version.c)
target_include_directories(shave-version PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/include")
target_link_libraries(shave-version PRIVATE shave_version_info)

if(SHAVE_BUILD_TESTS)
    add_library(unity STATIC tests/unity/framework/unity.c)
    target_include_directories(unity PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/tests/unity/framework")

    add_executable(test_version tests/unity/test_version.c)
    target_link_libraries(test_version PRIVATE unity shave_version_info)
    set_target_properties(test_version PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests"
    )
endif()

install(TARGETS shave-version RUNTIME DESTINATION bin)
install(PROGRAMS
    shave/shave.sh
    shave/shave-boilerplate.sh
    shave/shave-combiner.sh
    shave/shave-compiler.sh
    shave/shave-hash.sh
    shave/shave-output.sh
    shave/shave-parser.sh
    shave/shave-process.sh
    shave/shave-reader.sh
    shave/shave-validate.sh
    DESTINATION bin
)
