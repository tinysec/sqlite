#ifndef SQLITE_WDK7_COMPAT_STDINT_H
#define SQLITE_WDK7_COMPAT_STDINT_H

#if defined(_MSC_VER) && _MSC_VER < 1600
typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef short int16_t;
typedef unsigned short uint16_t;
typedef int int32_t;
typedef unsigned int uint32_t;
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;

#ifndef INT64_C
#define INT64_C(x) x##i64
#endif
#ifndef UINT64_C
#define UINT64_C(x) x##ui64
#endif
#ifndef INT32_C
#define INT32_C(x) x
#endif
#ifndef UINT32_C
#define UINT32_C(x) x##u
#endif
#ifndef INFINITY
#define INFINITY ((double)1.7976931348623158e308)
#endif

#ifdef _WIN64
typedef __int64 intptr_t;
typedef unsigned __int64 uintptr_t;
#else
typedef int intptr_t;
typedef unsigned int uintptr_t;
#endif
#else
#include_next <stdint.h>
#endif

#endif
