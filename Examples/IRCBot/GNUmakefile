include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = IRCBot
IRCBot_OBJC_FILES = main.m IRCBot.m 

ADDITIONAL_OBJCFLAGS = -Wall

ifeq ($(OBJC_RUNTIME_LIB), apple)
ADDITIONAL_OBJCFLAGS += -include GNUstep.h
IRCBot_TOOL_LIBS = -framework netclasses
else
IRCBot_TOOL_LIBS = -lnetclasses
endif

include $(GNUSTEP_MAKEFILES)/tool.make

