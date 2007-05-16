AM_OBJCFLAGS = $(libobjcx_CFLAGS) $(libSS_runloop_CFLAGS) -I$(top_srcdir)/Source -I$(top_srcdir)/Source/netclasses
AM_LDFLAGS = $(libobjcx_LIBS) $(libSS_runloop_LIBS)

lib_LTLIBRARIES= libnetclasses.la
libnetclasses_la_LDFLAGS= -version-info 1:0:1 $(OBJC_LIBS) $(DL_LIBS)
libnetclasses_la_SOURCES= \
IRCObject.m \
LineObject.m \
NetBase.m \
NetTCP.m

pkginclude_HEADERS= \
	netclasses/IRCObject.h \
	netclasses/LineObject.h \
	netclasses/NetBase.h \
	netclasses/NetTCP.h

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libnetclasses.pc
