include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = EchoServ
EchoServ_OBJC_FILES = main.m EchoServ.m

ADDITIONAL_OBJCFLAGS = -Wall

ifeq ($(OBJC_RUNTIME_LIB), apple)
ADDITIONAL_OBJCFLAGS += -include GNUstep.h $(ADDITIONAL_FRAMEWORK_DIRS)
EchoServ_TOOL_LIBS = -framework netclasses $(ADDITIONAL_FRAMEWORK_DIRS)
else
EchoServ_TOOL_LIBS = -lnetclasses
endif

include $(GNUSTEP_MAKEFILES)/tool.make

