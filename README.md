# sqlite

[![CI](https://github.com/tinysec/sqlite/actions/workflows/ci.yaml/badge.svg)](https://github.com/tinysec/sqlite/actions/workflows/ci.yaml)
[![SQLite 3.53.2](https://img.shields.io/badge/SQLite-3.53.2-blue)](https://github.com/tinysec/sqlite/releases/tag/v3.53.2)
[![Release](https://img.shields.io/badge/release-v3.53.2-green)](https://github.com/tinysec/sqlite/releases/tag/v3.53.2)

CMake package for the SQLite 3.53.2 amalgamation. It builds `sqlite3.c` into a
static library by default and can also build `sqlite3.dll` / `libsqlite3.so`
with `SQLITE_BUILD_SHARED=ON`.

This repository does not build SQLite tools. SQLite source code remains public
domain software from the original SQLite authors; see [LICENSE.md](LICENSE.md)
and <https://sqlite.org/copyright.html>.

## CMake

```cmake
include(FetchContent)

FetchContent_Declare(
    sqlite
    GIT_REPOSITORY https://github.com/tinysec/sqlite.git
    GIT_TAG v3.53.2
)

set(SQLITE_BUILD_SHARED OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(sqlite)

target_link_libraries(your_target PRIVATE SQLite::SQLite3)
```

For private SSH access:

```cmake
FetchContent_Declare(
    sqlite
    GIT_REPOSITORY git@github.com:tinysec/sqlite.git
    GIT_TAG v3.53.2
)
```

Use `v3.53.2` as the floating alias, or an immutable tag such as
`v3.53.2.<buildnumber>`.

## WDK7

Use `tinysec/setup-wdk7@v1`; it provides the WDK7 CMake toolchain and private
compatibility headers.

```yaml
- uses: tinysec/setup-wdk7@v1
  id: wdk7

- shell: cmd
  run: |
    cmake -S . -B build -G "%WDK7_CMAKE_GENERATOR%" ^
      -DCMAKE_TOOLCHAIN_FILE="%WDK7_CMAKE_TOOLCHAIN_FILE%" ^
      -DWDK7_ARCH=amd64 ^
      -DCMAKE_BUILD_TYPE=Release
    cmake --build build
```

## Prebuilt

Rolling release: <https://github.com/tinysec/sqlite/releases/tag/v3.53.2>

Prebuilt packages include `include/`, `lib/`, optional `bin/`, and `LICENSE.md`.
