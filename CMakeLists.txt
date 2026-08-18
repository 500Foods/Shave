cmake_minimum_required(VERSION 3.16)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" SHAVE_VERSION_RAW)
string(STRIP "${SHAVE_VERSION_RAW}" SHAVE_VERSION)

project(Shave VERSION ${SHAVE_VERSION} LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/src/version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/include/shave_version.h"
    @ONLY
)

add_executable(shave-version src/version.c)
target_include_directories(shave-version PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/include")

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
