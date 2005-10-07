AC_INIT([netclasses], [1.06], [aeruder@ksu.edu], [netclasses])
AC_PREREQ([2.57])
AC_SUBST(PACKAGE_VERSION)
AC_CONFIG_SRCDIR([Source/NetBase.m])
AC_CONFIG_HEADER([Source/config.h])
AC_CHECK_HEADERS([sys/types.h sys/socket.h])
AC_CHECK_TYPES([socklen_t],,,[
#include <sys/types.h>
#include <sys/socket.h>
])


AC_OUTPUT([ GNUmakefile
Source/GNUmakefile
])


