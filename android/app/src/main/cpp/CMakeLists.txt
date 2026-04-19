cmake_minimum_required(VERSION 3.22.1)
project(so_analysis)

include(FetchContent)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/patch_keystone_python3.cmake)

set(CAPSTONE_ARCHITECTURE_DEFAULT OFF)
set(CAPSTONE_ARM_SUPPORT ON)
set(CAPSTONE_ARM64_SUPPORT ON)
set(CAPSTONE_X86_SUPPORT ON)
set(CAPSTONE_MIPS_SUPPORT OFF)
set(CAPSTONE_PPC_SUPPORT OFF)
set(CAPSTONE_SPARC_SUPPORT OFF)
set(CAPSTONE_SYSZ_SUPPORT OFF)
set(CAPSTONE_XCORE_SUPPORT OFF)
set(CAPSTONE_M68K_SUPPORT OFF)
set(CAPSTONE_TMS320C64X_SUPPORT OFF)
set(CAPSTONE_M680X_SUPPORT OFF)
set(CAPSTONE_EVM_SUPPORT OFF)
set(CAPSTONE_BUILD_STATIC ON)
set(CAPSTONE_BUILD_SHARED OFF)
set(CAPSTONE_BUILD_TESTS OFF)
set(CAPSTONE_BUILD_CSTOOL OFF)

FetchContent_Declare(
    capstone
    GIT_REPOSITORY https://github.com/capstone-engine/capstone.git
    GIT_TAG        5.0.1
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(capstone)

find_package(Python3 COMPONENTS Interpreter)

set(KEYSTONE_BUILD_STATIC_RUNTIME ON CACHE BOOL "" FORCE)
set(BUILD_LIBS_ONLY ON CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(LLVM_TARGETS_TO_BUILD "ARM;AArch64" CACHE STRING "" FORCE)
if(Python3_Interpreter_FOUND)
    set(PYTHON_EXECUTABLE "${Python3_EXECUTABLE}" CACHE FILEPATH "" FORCE)
endif()

FetchContent_Declare(
    keystone
    GIT_REPOSITORY https://github.com/keystone-engine/keystone.git
    GIT_TAG        0.9.2
    GIT_SHALLOW    TRUE
)

FetchContent_GetProperties(keystone)
if(NOT keystone_POPULATED)
    FetchContent_Populate(keystone)
    patch_keystone_python3(${keystone_SOURCE_DIR})
    add_subdirectory(${keystone_SOURCE_DIR} ${keystone_BINARY_DIR} EXCLUDE_FROM_ALL)
endif()

set(LIEF_PREBUILT_DIR ${CMAKE_SOURCE_DIR}/../jniLibs/lief/${ANDROID_ABI})
set(LIEF_LIB ${LIEF_PREBUILT_DIR}/libLIEF.a)

if(EXISTS ${LIEF_LIB})
    add_library(LIEF STATIC IMPORTED)
    set_target_properties(LIEF PROPERTIES
        IMPORTED_LOCATION ${LIEF_LIB}
        INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_SOURCE_DIR}/../jniLibs/lief/include
    )

    add_library(so_analysis SHARED
        so_analysis_jni.cpp
    )

    add_library(memory_tool SHARED
        memory_tool_breakpoint.cpp
        memory_tool_jni.cpp
        memory_tool_engine.cpp
        memory_tool_instruction.cpp
        memory_tool_protocol.cpp
        memory_tool_reader.cpp
        memory_tool_regions.cpp
        memory_tool_scanner.cpp
        memory_tool_session.cpp
        memory_tool_utils.cpp
        memory_tool_value.cpp
    )

    target_include_directories(so_analysis PRIVATE
        ${CMAKE_SOURCE_DIR}/../jniLibs/lief/include
        ${capstone_SOURCE_DIR}/include
    )

    target_include_directories(memory_tool PRIVATE
        ${capstone_SOURCE_DIR}/include
        ${keystone_SOURCE_DIR}/include
    )

    target_link_libraries(so_analysis
        LIEF
        capstone
        android
        log
        z
    )

    target_link_libraries(memory_tool
        keystone
        capstone
        android
        log
    )

    foreach(native_target so_analysis memory_tool)
        target_compile_options(${native_target} PRIVATE
            -fexceptions
            -frtti
            -std=c++17
        )
    endforeach()
else()
    message(STATUS "LIEF not found for ${ANDROID_ABI}, skipping so_analysis and memory_tool")
endif()
