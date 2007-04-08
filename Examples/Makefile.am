AM_OBJCFLAGS = $(libobjcx_CFLAGS) $(libSS_runloop_CFLAGS)
AM_LDFLAGS = $(libobjcx_LIBS) $(libSS_runloop_LIBS)

noinst_PROGRAMS = exEchoServ exIRCBot exSimpleClient

exEchoServ_SOURCES = EchoServ/EchoServ.m EchoServ/main.m
exEchoServ_LDADD = ../Source/libnetclasses.la
exEchoServ_CPPFLAGS = -I$(top_srcdir)/Source 

exIRCBot_SOURCES = IRCBot/IRCBot.m IRCBot/main.m
exIRCBot_LDADD = ../Source/libnetclasses.la
exIRCBot_CPPFLAGS = -I$(top_srcdir)/Source 

exSimpleClient_SOURCES = SimpleClient/SimpleClient.m SimpleClient/main.m
exSimpleClient_LDADD = ../Source/libnetclasses.la
exSimpleClient_CPPFLAGS = -I$(top_srcdir)/Source 
