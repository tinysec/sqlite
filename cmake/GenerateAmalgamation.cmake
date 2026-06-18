if(NOT DEFINED SQLITE_SOURCE_DIR
        OR NOT DEFINED SQLITE_BINARY_DIR
        OR NOT DEFINED SQLITE_TSRC_DIR
        OR NOT DEFINED SQLITE_JIMSH
        OR NOT DEFINED SQLITE_SRC_VERIFY)
    message(FATAL_ERROR "SQLite amalgamation generation variables are incomplete")
endif()

file(REMOVE_RECURSE "${SQLITE_TSRC_DIR}")
file(MAKE_DIRECTORY "${SQLITE_TSRC_DIR}")

file(GLOB _src_files
    "${SQLITE_SOURCE_DIR}/src/*.c"
    "${SQLITE_SOURCE_DIR}/src/*.h")
file(GLOB _fts3_files
    "${SQLITE_SOURCE_DIR}/ext/fts3/*.c"
    "${SQLITE_SOURCE_DIR}/ext/fts3/*.h")
file(GLOB _rtree_files
    "${SQLITE_SOURCE_DIR}/ext/rtree/*.c"
    "${SQLITE_SOURCE_DIR}/ext/rtree/*.h")
file(GLOB _icu_files
    "${SQLITE_SOURCE_DIR}/ext/icu/*.c"
    "${SQLITE_SOURCE_DIR}/ext/icu/*.h")

set(_extra_files
    "${SQLITE_SOURCE_DIR}/ext/session/sqlite3session.c"
    "${SQLITE_SOURCE_DIR}/ext/session/sqlite3session.h"
    "${SQLITE_SOURCE_DIR}/ext/rbu/sqlite3rbu.c"
    "${SQLITE_SOURCE_DIR}/ext/rbu/sqlite3rbu.h"
    "${SQLITE_SOURCE_DIR}/ext/misc/stmt.c"
    "${SQLITE_BINARY_DIR}/sqlite3.h"
    "${SQLITE_BINARY_DIR}/parse.c"
    "${SQLITE_BINARY_DIR}/parse.h"
    "${SQLITE_BINARY_DIR}/opcodes.c"
    "${SQLITE_BINARY_DIR}/opcodes.h"
    "${SQLITE_BINARY_DIR}/pragma.h"
    "${SQLITE_BINARY_DIR}/ctime.c"
    "${SQLITE_BINARY_DIR}/keywordhash.h"
    "${SQLITE_BINARY_DIR}/fts5.c"
    "${SQLITE_BINARY_DIR}/fts5.h")

foreach(_file IN LISTS _src_files _fts3_files _rtree_files _icu_files _extra_files)
    if(EXISTS "${_file}")
        file(COPY "${_file}" DESTINATION "${SQLITE_TSRC_DIR}")
    endif()
endforeach()

file(REMOVE
    "${SQLITE_TSRC_DIR}/sqlite.h.in"
    "${SQLITE_TSRC_DIR}/parse.y")

file(WRITE "${SQLITE_TSRC_DIR}/sqlite_cfg.h"
"#ifndef SQLITE_CFG_H
#define SQLITE_CFG_H
#endif
")

execute_process(
    COMMAND "${SQLITE_JIMSH}" "${SQLITE_SOURCE_DIR}/tool/vdbe-compress.tcl"
    INPUT_FILE "${SQLITE_TSRC_DIR}/vdbe.c"
    OUTPUT_FILE "${SQLITE_BINARY_DIR}/vdbe.new"
    RESULT_VARIABLE _compress_result)
if(NOT _compress_result EQUAL 0)
    message(FATAL_ERROR "vdbe-compress.tcl failed with exit code ${_compress_result}")
endif()
file(RENAME "${SQLITE_BINARY_DIR}/vdbe.new" "${SQLITE_TSRC_DIR}/vdbe.c")

file(COPY "${SQLITE_SRC_VERIFY}" DESTINATION "${SQLITE_BINARY_DIR}")
get_filename_component(_src_verify_name "${SQLITE_SRC_VERIFY}" NAME)
if(NOT _src_verify_name STREQUAL "src-verify.exe")
    file(COPY "${SQLITE_SRC_VERIFY}" DESTINATION "${SQLITE_BINARY_DIR}")
    file(RENAME "${SQLITE_BINARY_DIR}/${_src_verify_name}" "${SQLITE_BINARY_DIR}/src-verify.exe")
endif()

execute_process(
    COMMAND "${SQLITE_JIMSH}" "${SQLITE_SOURCE_DIR}/tool/mksqlite3c.tcl"
        --srcdir "${SQLITE_TSRC_DIR}"
    WORKING_DIRECTORY "${SQLITE_BINARY_DIR}"
    RESULT_VARIABLE _amalgamation_result)
if(NOT _amalgamation_result EQUAL 0)
    message(FATAL_ERROR "mksqlite3c.tcl failed with exit code ${_amalgamation_result}")
endif()

file(COPY "${SQLITE_TSRC_DIR}/sqlite3ext.h" DESTINATION "${SQLITE_BINARY_DIR}")
file(COPY "${SQLITE_SOURCE_DIR}/ext/session/sqlite3session.h" DESTINATION "${SQLITE_BINARY_DIR}")
