include $(GNUSTEP_MAKEFILES)/common.make

FRAMEWORK_NAME = netclasses 

netclasses_OBJC_FILES = NetBase.m NetTCP.m LineObject.m IRCObject.m 
netclasses_HEADER_FILES = NetBase.h NetTCP.h IRCObject.h LineObject.h 
netclasses_CURRENT_VERSION_NAME=1.0.2
netclasses_DEPLOY_WITH_CURRENT_VERSION=yes

ADDITIONAL_OBJCFLAGS = -Wall

ifeq ($(OBJC_RUNTIME_LIB), apple)
ADDITIONAL_OBJCFLAGS += -include GNUstep.h
endif

GUI_LIB =

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
