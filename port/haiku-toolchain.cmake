# CMake toolchain for Haiku x86_64 with the Haiku build's cross tools and
# the sysroot port/mesa-build.sh uses.
#   cmake -DCMAKE_TOOLCHAIN_FILE=port/haiku-toolchain.cmake ...
get_filename_component(HAIKU_PORT_TOP "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(HAIKU_CROSS "${HAIKU_PORT_TOP}/generated.x86_64/cross-tools-x86_64")

set(CMAKE_SYSTEM_NAME Haiku)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER "${HAIKU_CROSS}/bin/x86_64-unknown-haiku-gcc")
set(CMAKE_CXX_COMPILER "${HAIKU_CROSS}/bin/x86_64-unknown-haiku-g++")
set(CMAKE_SYSROOT "${HAIKU_CROSS}/sysroot")
set(CMAKE_FIND_ROOT_PATH "${HAIKU_CROSS}/sysroot")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
