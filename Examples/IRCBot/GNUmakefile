include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = IRCBot
IRCBot_OBJC_FILES = main.m IRCBot.m 

IRCBot_TOOL_LIBS = -lnetclasses

ADDITIONAL_OBJCFLAGS = -Wall

ifeq ($(OBJC_RUNTIME_LIB), apple)
ADDITIONAL_OBJCFLAGS += -include GNUstep.h
endif

include $(GNUSTEP_MAKEFILES)/tool.make

