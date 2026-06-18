cmake_minimum_required(VERSION 3.20)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.15")
    cmake_policy(SET CMP0091 NEW)
endif()

set(SQLITE_UPSTREAM_VERSION "3.53.2" CACHE STRING "Upstream SQLite source version")
set(SQLITE_BUILD_NUMBER "0" CACHE STRING "Floating release build number for ${SQLITE_UPSTREAM_VERSION}.<buildnumber>")

if(NOT SQLITE_UPSTREAM_VERSION STREQUAL "3.53.2")
    message(FATAL_ERROR "This source tree is fixed to SQLite ${SQLITE_UPSTREAM_VERSION}; expected 3.53.2")
endif()

if(NOT SQLITE_BUILD_NUMBER MATCHES "^[0-9]+$")
    message(FATAL_ERROR "SQLITE_BUILD_NUMBER must be a decimal build number")
endif()

if(NOT DEFINED SQLITE_VERSION OR SQLITE_VERSION STREQUAL "")
    set(SQLITE_VERSION "${SQLITE_UPSTREAM_VERSION}.${SQLITE_BUILD_NUMBER}")
endif()

if(NOT SQLITE_VERSION MATCHES "^3\\.53\\.2\\.[0-9]+$")
    message(FATAL_ERROR "SQLITE_VERSION must be 3.53.2.<buildnumber>")
endif()

project(sqlite VERSION "${SQLITE_VERSION}" LANGUAGES C)

# This fork is consumed as a local CMake dependency (FetchContent /
# add_subdirectory), so it exposes ordinary CMake targets directly. It does not
# generate install()/find_package() package metadata.

option(SQLITE_BUILD_SHARED "Also build the sqlite3 DLL/shared library" OFF)
option(SQLITE_ENABLE_FTS5 "Enable FTS5 in the amalgamation build" ON)
option(SQLITE_ENABLE_RTREE "Enable RTree in the amalgamation build" ON)
option(SQLITE_ENABLE_SESSION "Enable session extension APIs" ON)
option(SQLITE_ENABLE_COLUMN_METADATA "Enable column metadata APIs" ON)
option(SQLITE_OMIT_LOAD_EXTENSION "Omit runtime extension loading" OFF)

set(_sqlite_wdk7_default_mode "")
set(_sqlite_wdk7_default_mode_is_kernel OFF)
if(WDK7 AND DEFINED WDK7_DEFAULT_MODE)
    string(TOUPPER "${WDK7_DEFAULT_MODE}" _sqlite_wdk7_default_mode)
    if(_sqlite_wdk7_default_mode STREQUAL "KERNEL")
        set(_sqlite_wdk7_default_mode_is_kernel ON)
    endif()
endif()

set(_sqlite_kernel_mode_default OFF)
if(_sqlite_wdk7_default_mode_is_kernel)
    set(_sqlite_kernel_mode_default ON)
endif()
option(SQLITE_KERNEL_MODE
    "Build for Windows kernel-mode consumers"
    "${_sqlite_kernel_mode_default}")

if(SQLITE_KERNEL_MODE AND NOT WDK7)
    message(FATAL_ERROR "SQLITE_KERNEL_MODE is currently supported only with cmake/wdk7.cmake")
endif()

set(SQLITE_AMALGAMATION_C "${CMAKE_CURRENT_SOURCE_DIR}/sqlite3.c")
set(SQLITE_AMALGAMATION_H "${CMAKE_CURRENT_SOURCE_DIR}/sqlite3.h")

if(NOT EXISTS "${SQLITE_AMALGAMATION_C}" OR NOT EXISTS "${SQLITE_AMALGAMATION_H}")
    message(FATAL_ERROR "This package builds from checked-in sqlite3.c and sqlite3.h only")
endif()

add_custom_target(sqlite_amalgamation
    DEPENDS
        "${SQLITE_AMALGAMATION_C}"
        "${SQLITE_AMALGAMATION_H}")

function(_sqlite_apply_library_settings target_name)
    add_dependencies("${target_name}" sqlite_amalgamation)

    target_include_directories("${target_name}"
        PUBLIC
            "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>")

    target_compile_definitions("${target_name}"
        PUBLIC
            SQLITE_THREADSAFE=1)

    if(SQLITE_ENABLE_FTS5)
        target_compile_definitions("${target_name}" PUBLIC SQLITE_ENABLE_FTS5=1)
    endif()
    if(SQLITE_ENABLE_RTREE)
        target_compile_definitions("${target_name}" PUBLIC SQLITE_ENABLE_RTREE=1 SQLITE_ENABLE_GEOPOLY=1)
    endif()
    if(SQLITE_ENABLE_SESSION)
        target_compile_definitions("${target_name}" PUBLIC SQLITE_ENABLE_SESSION=1 SQLITE_ENABLE_PREUPDATE_HOOK=1)
    endif()
    if(SQLITE_ENABLE_COLUMN_METADATA)
        target_compile_definitions("${target_name}" PUBLIC SQLITE_ENABLE_COLUMN_METADATA=1)
    endif()
    if(SQLITE_OMIT_LOAD_EXTENSION)
        target_compile_definitions("${target_name}" PUBLIC SQLITE_OMIT_LOAD_EXTENSION=1)
    endif()

    if(MSVC)
        target_compile_definitions("${target_name}" PRIVATE _CRT_SECURE_NO_WARNINGS)
        target_compile_options("${target_name}" PRIVATE /W3)
    endif()

    if(WDK7 AND TARGET WDK7::User AND NOT _sqlite_wdk7_default_mode_is_kernel)
        target_include_directories("${target_name}" BEFORE PRIVATE
            "${CMAKE_CURRENT_SOURCE_DIR}/cmake/wdk7-compat/include")
        target_compile_definitions("${target_name}" PRIVATE SQLITE_DISABLE_INTRINSIC=1)
        target_compile_definitions("${target_name}" PRIVATE SQLITE_OMIT_LOCALTIME=1)
        target_link_libraries("${target_name}" PUBLIC WDK7::User)
    endif()

    if(SQLITE_KERNEL_MODE)
        target_compile_definitions("${target_name}"
            PUBLIC
                SQLITE_OS_OTHER=1
                SQLITE_OMIT_LOAD_EXTENSION=1
                SQLITE_OMIT_WAL=1
                SQLITE_TEMP_STORE=3
                SQLITE_MUTEX_NOOP=1
                _KERNEL_MODE)

        if(TARGET WDK7::Kernel AND NOT _sqlite_wdk7_default_mode_is_kernel)
            target_include_directories("${target_name}" BEFORE PRIVATE
                "${CMAKE_CURRENT_SOURCE_DIR}/cmake/wdk7-compat/include")
            target_link_libraries("${target_name}" PUBLIC WDK7::Kernel)
        endif()
    endif()

    set_target_properties("${target_name}" PROPERTIES
        VERSION "${PROJECT_VERSION}"
        POSITION_INDEPENDENT_CODE ON)
endfunction()

add_library(sqlite3_static STATIC
    "${SQLITE_AMALGAMATION_C}"
    "${SQLITE_AMALGAMATION_H}"
    "sqlite3ext.h")
add_library(SQLite::SQLite3 ALIAS sqlite3_static)
add_library(sqlite::sqlite3 ALIAS sqlite3_static)
add_library(sqlite::sqlite3_static ALIAS sqlite3_static)
_sqlite_apply_library_settings(sqlite3_static)
set_target_properties(sqlite3_static PROPERTIES OUTPUT_NAME "sqlite3_static")

if(SQLITE_BUILD_SHARED)
    add_library(sqlite3 SHARED
        "${SQLITE_AMALGAMATION_C}"
        "${SQLITE_AMALGAMATION_H}"
        "sqlite3ext.h")
    _sqlite_apply_library_settings(sqlite3)
    if(WIN32)
        target_compile_definitions(sqlite3 PRIVATE "SQLITE_API=__declspec(dllexport)")
    endif()
    set_target_properties(sqlite3 PROPERTIES OUTPUT_NAME "sqlite3")
endif()
