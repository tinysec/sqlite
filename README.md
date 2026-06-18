# sqlite

[![CI](https://github.com/tinysec/sqlite/actions/workflows/ci.yaml/badge.svg)](https://github.com/tinysec/sqlite/actions/workflows/ci.yaml)
[![SQLite 3.53.2](https://img.shields.io/badge/SQLite-3.53.2-blue)](https://github.com/tinysec/sqlite/releases/tag/v3.53.2)
[![Release alias](https://img.shields.io/badge/release-v3.53.2-green)](https://github.com/tinysec/sqlite/releases/tag/v3.53.2)

This repository packages SQLite 3.53.2 as CMake-consumable static and shared
libraries for Windows and Linux. It is intended for projects that need SQLite as
a direct CMake dependency, including Windows Driver Kit 7.1 based builds.

The build does not compile SQLite command-line tools by default in CI release
artifacts. Release assets contain only headers, libraries, DLLs/shared objects,
and the upstream SQLite license notice.

## License

SQLite source code is public domain software from the original SQLite authors.
This repository does not change SQLite ownership, copyright status, or license
terms. See [LICENSE.md](LICENSE.md) and the upstream SQLite copyright page:
<https://sqlite.org/copyright.html>.

## Features

- SQLite 3.53.2 amalgamation-based library builds.
- Static library and DLL/shared library targets.
- Modern Visual Studio, WDK7, and Linux builds.
- CMake `FetchContent` and `add_subdirectory` consumption.
- CI matrix artifacts for x64 and x86.
- Immutable releases named `v3.53.2.<buildnumber>`.
- Rolling release alias `v3.53.2` that points to the latest build.

## CMake Targets

When added to a CMake project, the repository exposes these targets:

| Target | Description |
| --- | --- |
| `SQLite::SQLite3` | Preferred target. Uses the shared library when enabled, otherwise static. |
| `sqlite::sqlite3` | Lowercase alias for `SQLite::SQLite3`. |
| `sqlite::sqlite3_static` | Static library target. |
| `sqlite3` | Shared library target when `SQLITE_BUILD_SHARED=ON`. |
| `sqlite3_static` | Static library target when `SQLITE_BUILD_STATIC=ON`. |

Useful options:

| Option | Default | Description |
| --- | --- | --- |
| `SQLITE_BUILD_STATIC` | `ON` | Build `sqlite3_static`. |
| `SQLITE_BUILD_SHARED` | `ON` | Build `sqlite3` DLL/shared library. |
| `SQLITE_BUILD_TOOLS` | `ON` | Build source-generation tools when pregenerated sources are not used. |
| `SQLITE_USE_PREGENERATED` | `ON` when `sqlite3.c` and `sqlite3.h` exist | Use checked-in amalgamation files. |
| `SQLITE_BUILD_NUMBER` | `0` | Forms `3.53.2.<buildnumber>`. |

## Use From Source

For a private GitHub repository, make sure the build environment has GitHub
credentials before CMake configures the project.

```cmake
include(FetchContent)

FetchContent_Declare(
    sqlite
    GIT_REPOSITORY https://github.com/tinysec/sqlite.git
    GIT_TAG v3.53.2
)

set(SQLITE_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(SQLITE_BUILD_SHARED OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(sqlite)

target_link_libraries(your_target PRIVATE SQLite::SQLite3)
```

Use the rolling alias `v3.53.2` for the latest 3.53.2 build line, or use an
immutable build tag such as `v3.53.2.123` when the exact artifact source must not
move.

For SSH-authenticated private access:

```cmake
FetchContent_Declare(
    sqlite
    GIT_REPOSITORY git@github.com:tinysec/sqlite.git
    GIT_TAG v3.53.2
)
```

## Use With WDK7

CMake loads the toolchain file before `FetchContent` downloads dependencies, so
the WDK7 toolchain file must be available locally before configure starts. You
can copy `cmake/wdk7.cmake` into your project or reference it from an existing
checkout.

```bat
cmake -S . -B build-wdk7 -G "NMake Makefiles" ^
  -DCMAKE_TOOLCHAIN_FILE=D:\path\to\sqlite\cmake\wdk7.cmake ^
  -DWDK7_ARCH=amd64 ^
  -DWDK7_DEFAULT_MODE=USER ^
  -DSQLITE_BUILD_STATIC=ON ^
  -DSQLITE_BUILD_SHARED=ON ^
  -DCMAKE_BUILD_TYPE=Release

cmake --build build-wdk7
```

Use `-DWDK7_ARCH=i386` for 32-bit builds.

## Download Prebuilt Libraries

The rolling release is:

```text
https://github.com/tinysec/sqlite/releases/tag/v3.53.2
```

Stable asset names on the rolling release:

| Asset | Toolchain |
| --- | --- |
| `sqlite-linux-x64.tar.gz` | Linux x64 |
| `sqlite-linux-x86.tar.gz` | Linux x86 |
| `sqlite-msvc-x64-mt.zip` | Visual Studio x64, static CRT |
| `sqlite-msvc-x64-md.zip` | Visual Studio x64, dynamic CRT |
| `sqlite-msvc-x86-mt.zip` | Visual Studio x86, static CRT |
| `sqlite-msvc-x86-md.zip` | Visual Studio x86, dynamic CRT |
| `sqlite-wdk7-x64.zip` | WDK7 x64 |
| `sqlite-wdk7-x86.zip` | WDK7 x86 |

Example direct download:

```text
https://github.com/tinysec/sqlite/releases/download/v3.53.2/sqlite-wdk7-x64.zip
```

Each package contains:

```text
bin/      DLL or shared object when applicable
lib/      static library and import library when applicable
include/  sqlite3.h and sqlite3ext.h
LICENSE.md
```

## Standalone Builds

Visual Studio:

```bat
cmake -S . -B build-msvc -G "Visual Studio 17 2022" -A x64 ^
  -DSQLITE_BUILD_STATIC=ON ^
  -DSQLITE_BUILD_SHARED=ON

cmake --build build-msvc --config Release --parallel
```

Linux:

```sh
cmake -S . -B build-linux \
  -DCMAKE_BUILD_TYPE=Release \
  -DSQLITE_BUILD_STATIC=ON \
  -DSQLITE_BUILD_SHARED=ON

cmake --build build-linux --parallel
```

WDK7:

```bat
cmake -S . -B build-wdk7 -G "NMake Makefiles" ^
  -DCMAKE_TOOLCHAIN_FILE=cmake\wdk7.cmake ^
  -DWDK7_ARCH=amd64 ^
  -DWDK7_DEFAULT_MODE=USER ^
  -DCMAKE_BUILD_TYPE=Release

cmake --build build-wdk7
```
