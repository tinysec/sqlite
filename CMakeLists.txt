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
option(SQLITE_BUILD_TOOLS "Build SQLite source-generation tools" ON)

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

set(SQLITE_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(SQLITE_TSRC_DIR "${SQLITE_GENERATED_DIR}/tsrc")
file(MAKE_DIRECTORY "${SQLITE_GENERATED_DIR}")

set(_sqlite_use_pregenerated_default OFF)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/sqlite3.c"
        AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/sqlite3.h")
    set(_sqlite_use_pregenerated_default ON)
endif()
option(SQLITE_USE_PREGENERATED
    "Use checked-in sqlite3.c/sqlite3.h instead of generating the amalgamation"
    "${_sqlite_use_pregenerated_default}")

if(SQLITE_USE_PREGENERATED)
    set(SQLITE_AMALGAMATION_C "${CMAKE_CURRENT_SOURCE_DIR}/sqlite3.c")
    set(SQLITE_AMALGAMATION_H "${CMAKE_CURRENT_SOURCE_DIR}/sqlite3.h")

    if(NOT EXISTS "${SQLITE_AMALGAMATION_C}" OR NOT EXISTS "${SQLITE_AMALGAMATION_H}")
        message(FATAL_ERROR
            "SQLITE_USE_PREGENERATED requires sqlite3.c and sqlite3.h in the source root")
    endif()

    add_custom_target(sqlite_amalgamation
        DEPENDS
            "${SQLITE_AMALGAMATION_C}"
            "${SQLITE_AMALGAMATION_H}")
else()
file(TO_CMAKE_PATH "${CMAKE_CURRENT_SOURCE_DIR}" SQLITE_SOURCE_DIR_TCL)
file(TO_CMAKE_PATH "${SQLITE_GENERATED_DIR}" SQLITE_GENERATED_DIR_TCL)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/tool/mksqlite3h.tcl" _sqlite_mksqlite3h_tcl)
string(REGEX REPLACE
    "\\[file normalize \\$TOP/VERSION\\]"
    [=[$TOP/VERSION]=]
    _sqlite_mksqlite3h_tcl
    "${_sqlite_mksqlite3h_tcl}")
file(WRITE "${SQLITE_GENERATED_DIR}/mksqlite3h-cmake.tcl" "${_sqlite_mksqlite3h_tcl}")

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/ext/fts5/tool/mkfts5c.tcl" _sqlite_mkfts5c_tcl)
string(REGEX REPLACE
    "set srcdir \\[file dirname \\[file dirname \\[file normalize \\[info script\\]\\]\\]\\]"
    "set srcdir \"${SQLITE_SOURCE_DIR_TCL}/ext/fts5\""
    _sqlite_mkfts5c_tcl
    "${_sqlite_mkfts5c_tcl}")
file(WRITE "${SQLITE_GENERATED_DIR}/mkfts5c-cmake.tcl" "${_sqlite_mkfts5c_tcl}")

add_executable(sqlite_jimsh EXCLUDE_FROM_ALL "autosetup/jimsh0.c")
add_executable(sqlite_lemon EXCLUDE_FROM_ALL "tool/lemon.c")
add_executable(sqlite_mkkeywordhash EXCLUDE_FROM_ALL "tool/mkkeywordhash.c")
add_executable(sqlite_mksourceid EXCLUDE_FROM_ALL "tool/mksourceid.c")
add_executable(sqlite_src_verify EXCLUDE_FROM_ALL "tool/src-verify.c")

if(WDK7)
    enable_language(CXX)
    set_source_files_properties("autosetup/jimsh0.c" PROPERTIES LANGUAGE CXX)
    target_compile_definitions(sqlite_jimsh PRIVATE ETIMEDOUT=10060 snprintf=_snprintf)
endif()

if(MSVC)
    foreach(_sqlite_tool
            sqlite_jimsh
            sqlite_lemon
            sqlite_mkkeywordhash
            sqlite_mksourceid
            sqlite_src_verify)
        target_compile_options("${_sqlite_tool}" PRIVATE /W3)
    endforeach()
endif()

add_custom_command(
    OUTPUT
        "${SQLITE_GENERATED_DIR}/parse.c"
        "${SQLITE_GENERATED_DIR}/parse.h"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/src/parse.y"
        "${SQLITE_GENERATED_DIR}/parse.y"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/tool/lempar.c"
        "${SQLITE_GENERATED_DIR}/lempar.c"
    COMMAND sqlite_lemon -S parse.y
    DEPENDS sqlite_lemon "src/parse.y" "tool/lempar.c"
    WORKING_DIRECTORY "${SQLITE_GENERATED_DIR}"
    VERBATIM)

add_custom_command(
    OUTPUT "${SQLITE_GENERATED_DIR}/opcodes.h"
    COMMAND "${CMAKE_COMMAND}"
        -DSQLITE_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DSQLITE_BINARY_DIR=${SQLITE_GENERATED_DIR}
        -DSQLITE_JIMSH=$<TARGET_FILE:sqlite_jimsh>
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateOpcodesHeader.cmake"
    DEPENDS
        sqlite_jimsh
        "${SQLITE_GENERATED_DIR}/parse.h"
        "src/vdbe.c"
        "tool/mkopcodeh.tcl"
    VERBATIM)

add_custom_command(
    OUTPUT "${SQLITE_GENERATED_DIR}/opcodes.c"
    COMMAND sqlite_jimsh
        "${CMAKE_CURRENT_SOURCE_DIR}/tool/mkopcodec.tcl"
        "${SQLITE_GENERATED_DIR}/opcodes.h"
        > "${SQLITE_GENERATED_DIR}/opcodes.c"
    DEPENDS
        sqlite_jimsh
        "${SQLITE_GENERATED_DIR}/opcodes.h"
        "tool/mkopcodec.tcl"
    VERBATIM)

add_custom_command(
    OUTPUT "${SQLITE_GENERATED_DIR}/pragma.h"
    COMMAND sqlite_jimsh
        "${CMAKE_CURRENT_SOURCE_DIR}/tool/mkpragmatab.tcl"
    DEPENDS sqlite_jimsh "tool/mkpragmatab.tcl"
    WORKING_DIRECTORY "${SQLITE_GENERATED_DIR}"
    VERBATIM)

add_custom_command(
    OUTPUT "${SQLITE_GENERATED_DIR}/ctime.c"
    COMMAND sqlite_jimsh
        "${CMAKE_CURRENT_SOURCE_DIR}/tool/mkctimec.tcl"
    DEPENDS sqlite_jimsh "tool/mkctimec.tcl"
    WORKING_DIRECTORY "${SQLITE_GENERATED_DIR}"
    VERBATIM)

add_custom_command(
    OUTPUT "${SQLITE_GENERATED_DIR}/keywordhash.h"
    COMMAND sqlite_mkkeywordhash > "${SQLITE_GENERATED_DIR}/keywordhash.h"
    DEPENDS sqlite_mkkeywordhash
    VERBATIM)

add_custom_command(
    OUTPUT "${SQLITE_GENERATED_DIR}/sqlite3.h"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "$<TARGET_FILE:sqlite_mksourceid>"
        "${SQLITE_GENERATED_DIR}/mksourceid.exe"
    COMMAND sqlite_jimsh
        "${SQLITE_GENERATED_DIR}/mksqlite3h-cmake.tcl"
        "${SQLITE_SOURCE_DIR_TCL}"
        -o "${SQLITE_GENERATED_DIR}/sqlite3.h"
    DEPENDS
        sqlite_jimsh
        sqlite_mksourceid
        "src/sqlite.h.in"
        "manifest"
        "manifest.uuid"
        "VERSION"
        "tool/mksqlite3h.tcl"
    WORKING_DIRECTORY "${SQLITE_GENERATED_DIR}"
    VERBATIM)

add_custom_command(
    OUTPUT
        "${SQLITE_GENERATED_DIR}/fts5parse.c"
        "${SQLITE_GENERATED_DIR}/fts5parse.h"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/ext/fts5/fts5parse.y"
        "${SQLITE_GENERATED_DIR}/fts5parse.y"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/tool/lempar.c"
        "${SQLITE_GENERATED_DIR}/lempar.c"
    COMMAND sqlite_lemon -S fts5parse.y
    DEPENDS sqlite_lemon "ext/fts5/fts5parse.y" "tool/lempar.c"
    WORKING_DIRECTORY "${SQLITE_GENERATED_DIR}"
    VERBATIM)

set(_sqlite_fts5_sources
    "ext/fts5/fts5.h"
    "ext/fts5/fts5Int.h"
    "ext/fts5/fts5_aux.c"
    "ext/fts5/fts5_buffer.c"
    "ext/fts5/fts5_config.c"
    "ext/fts5/fts5_expr.c"
    "ext/fts5/fts5_hash.c"
    "ext/fts5/fts5_index.c"
    "ext/fts5/fts5_main.c"
    "ext/fts5/fts5_storage.c"
    "ext/fts5/fts5_tokenize.c"
    "ext/fts5/fts5_unicode2.c"
    "ext/fts5/fts5_varint.c"
    "ext/fts5/fts5_vocab.c"
    "ext/fts5/tool/mkfts5c.tcl")

add_custom_command(
    OUTPUT
        "${SQLITE_GENERATED_DIR}/fts5.c"
        "${SQLITE_GENERATED_DIR}/fts5.h"
    COMMAND sqlite_jimsh
        "${SQLITE_GENERATED_DIR}/mkfts5c-cmake.tcl"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/ext/fts5/fts5.h"
        "${SQLITE_GENERATED_DIR}/fts5.h"
    DEPENDS
        sqlite_jimsh
        "${SQLITE_GENERATED_DIR}/fts5parse.c"
        "${SQLITE_GENERATED_DIR}/fts5parse.h"
        ${_sqlite_fts5_sources}
    WORKING_DIRECTORY "${SQLITE_GENERATED_DIR}"
    VERBATIM)

add_custom_command(
    OUTPUT "${SQLITE_GENERATED_DIR}/sqlite3.c"
    COMMAND "${CMAKE_COMMAND}"
        -DSQLITE_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DSQLITE_BINARY_DIR=${SQLITE_GENERATED_DIR}
        -DSQLITE_TSRC_DIR=${SQLITE_TSRC_DIR}
        -DSQLITE_JIMSH=$<TARGET_FILE:sqlite_jimsh>
        -DSQLITE_SRC_VERIFY=$<TARGET_FILE:sqlite_src_verify>
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateAmalgamation.cmake"
    DEPENDS
        sqlite_jimsh
        sqlite_src_verify
        "${SQLITE_GENERATED_DIR}/sqlite3.h"
        "${SQLITE_GENERATED_DIR}/parse.c"
        "${SQLITE_GENERATED_DIR}/parse.h"
        "${SQLITE_GENERATED_DIR}/opcodes.c"
        "${SQLITE_GENERATED_DIR}/opcodes.h"
        "${SQLITE_GENERATED_DIR}/pragma.h"
        "${SQLITE_GENERATED_DIR}/ctime.c"
        "${SQLITE_GENERATED_DIR}/keywordhash.h"
        "${SQLITE_GENERATED_DIR}/fts5.c"
        "${SQLITE_GENERATED_DIR}/fts5.h"
        "tool/mksqlite3c.tcl"
        "tool/vdbe-compress.tcl"
    VERBATIM)

add_custom_target(sqlite_amalgamation
    DEPENDS
        "${SQLITE_GENERATED_DIR}/sqlite3.c"
        "${SQLITE_GENERATED_DIR}/sqlite3.h")
set(SQLITE_AMALGAMATION_C "${SQLITE_GENERATED_DIR}/sqlite3.c")
set(SQLITE_AMALGAMATION_H "${SQLITE_GENERATED_DIR}/sqlite3.h")
endif()

function(_sqlite_apply_library_settings target_name)
    add_dependencies("${target_name}" sqlite_amalgamation)

    target_include_directories("${target_name}"
        PUBLIC
            "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>"
            "$<BUILD_INTERFACE:${SQLITE_GENERATED_DIR}>"
            "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>")

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
    "src/sqlite3ext.h")
add_library(SQLite::SQLite3 ALIAS sqlite3_static)
add_library(sqlite::sqlite3 ALIAS sqlite3_static)
add_library(sqlite::sqlite3_static ALIAS sqlite3_static)
_sqlite_apply_library_settings(sqlite3_static)
set_target_properties(sqlite3_static PROPERTIES OUTPUT_NAME "sqlite3_static")

if(SQLITE_BUILD_SHARED)
    add_library(sqlite3 SHARED
        "${SQLITE_AMALGAMATION_C}"
        "${SQLITE_AMALGAMATION_H}"
        "src/sqlite3ext.h")
    _sqlite_apply_library_settings(sqlite3)
    if(WIN32)
        target_compile_definitions(sqlite3 PRIVATE "SQLITE_API=__declspec(dllexport)")
    endif()
    set_target_properties(sqlite3 PROPERTIES OUTPUT_NAME "sqlite3")
endif()

if(SQLITE_BUILD_TOOLS AND NOT SQLITE_USE_PREGENERATED)
    add_custom_target(sqlite_tools
        DEPENDS
            sqlite_jimsh
            sqlite_lemon
            sqlite_mkkeywordhash
            sqlite_mksourceid
            sqlite_src_verify)
endif()
