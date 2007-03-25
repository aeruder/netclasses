dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.52)
AC_INIT(Source/config.h.in)
AC_REVISION($Revision$) dnl
AM_CONFIG_HEADER(Source/config.h)
AC_CANONICAL_SYSTEM
AC_VALIDATE_CACHED_SYSTEM_TUPLE(
	rm $cache_file
	echo restart configure
	exit 1
)

dnl This is the only place where the package version appears
AM_INIT_AUTOMAKE(netclasses, 1.07)

dnl Define the proper name and extra version numbers for package
PROGRAM=netclasses
RPMVERSION=`echo $VERSION | tr - _`
AC_SUBST(RPMVERSION)

AC_DEFINE_UNQUOTED(PROGRAM,	"$PROGRAM", ["Proper" package name])
AC_SUBST(PROGRAM)

##########################
# Set up the OBJC compiler
##########################

# If CC is set and OBJC isn't, set OBJC to CC
if test "x${CC}" != x -a "x${OBJC}" = x; then
	OBJC="$CC"
fi
if test "x${CPP}" != x -a "x${OBJCPP}" = x; then
	OBJCPP="$CPP"
fi

AC_LANG_C
AC_LANG_OBJC
dnl This is a hack to get automake to do fastdeps for objc
AM_CONDITIONAL(am__fastdepOBJC, true)

if test "x${CFLAGS}" = x; then
	CFLAGS=""
fi
if test "x${OBJCFLAGS}" = x; then
	OBJCFLAGS=""
fi

AC_PROG_CC
AC_PROG_CPP
AC_PROG_OBJC
AC_PROG_OBJCPP
AC_PROG_LIBTOOL
##########################
##########################


###########################################
# Check for libobjcx and make sure it works 
###########################################

PKG_CHECK_MODULES(libobjcx, libobjcx)
PKG_CHECK_MODULES(libSS_runloop, libSS_runloop)
AC_LANG([Objective C])
AC_MSG_CHECKING(whether libobjcx program can build)
ac_save_OBJCFLAGS="$OBJCFLAGS"
ac_save_LIBS="$LIBS"
OBJCFLAGS="$OBJCFLAGS $libobjcx_CFLAGS $libSS_runloop_CFLAGS"
LIBS="$LIBS $libobjcx_LIBS $libSS_runloop_LIBS"
AC_LINK_IFELSE([[
#include <Foundation/Foundation.h>
int main(void) {
  NSAutoreleasePool *apr = [NSAutoreleasePool new];
  [apr release];
  return 0;
}
]], AC_MSG_RESULT(yes), [
AC_MSG_RESULT(no)
echo "Error compiling libobjcx program, check config.log"
exit 1
])
OBJCFLAGS="$ac_save_OBJCFLAGS"
LIBS="$ac_save_LIBS"
##########################
##########################


##########################
dnl Finalization of *CFLAGS, LDFLAGS, and *LIBS
##########################
AC_SUBST(CFLAGS)
AC_SUBST(LDFLAGS)
AC_SUBST(LIBS)
AC_SUBST(libobjcx_CFLAGS)
AC_SUBST(libobjcx_LIBS)
AC_SUBST(libSS_runloop_CFLAGS)
AC_SUBST(libSS_runloop_LIBS)
##########################
##########################

AC_SUBST(PACKAGE_VERSION)
AC_CHECK_HEADERS([sys/types.h sys/socket.h])
AC_CHECK_TYPES([socklen_t],,,[
#include <sys/types.h>
#include <sys/socket.h>
])

AC_CACHE_SAVE

dnl Output files
AC_OUTPUT(
	Makefile
	Source/Makefile
	Examples/Makefile
)

