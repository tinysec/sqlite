if(NOT DEFINED SQLITE_SOURCE_DIR OR NOT DEFINED SQLITE_BINARY_DIR OR NOT DEFINED SQLITE_JIMSH)
    message(FATAL_ERROR "SQLITE_SOURCE_DIR, SQLITE_BINARY_DIR, and SQLITE_JIMSH are required")
endif()

file(READ "${SQLITE_BINARY_DIR}/parse.h" _parse_h)
file(READ "${SQLITE_SOURCE_DIR}/src/vdbe.c" _vdbe_c)
file(WRITE "${SQLITE_BINARY_DIR}/opcodes-input.txt" "${_parse_h}${_vdbe_c}")

execute_process(
    COMMAND "${SQLITE_JIMSH}" "${SQLITE_SOURCE_DIR}/tool/mkopcodeh.tcl"
    INPUT_FILE "${SQLITE_BINARY_DIR}/opcodes-input.txt"
    OUTPUT_FILE "${SQLITE_BINARY_DIR}/opcodes.h"
    RESULT_VARIABLE _result)
if(NOT _result EQUAL 0)
    message(FATAL_ERROR "mkopcodeh.tcl failed with exit code ${_result}")
endif()
