include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = IRCBot
IRCBot_OBJC_FILES = main.m IRCBot.m 

ADDITIONAL_OBJCFLAGS = -Wall

ifeq ($(OBJC_RUNTIME_LIB), apple)
ADDITIONAL_OBJCFLAGS += -include GNUstep.h $(ADDITIONAL_FRAMEWORK_DIRS)
IRCBot_TOOL_LIBS = -framework netclasses $(ADDITIONAL_FRAMEWORK_DIRS)
else
IRCBot_TOOL_LIBS = -lnetclasses
endif

GUI_LIB =

include $(GNUSTEP_MAKEFILES)/tool.make

