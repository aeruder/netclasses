include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = conversions

conversions_OBJC_FILES = conversions.m 
conversions_COPY_INTO_DIR = .

ADDITIONAL_OBJCFLAGS = -Wall

ifeq ($(OBJC_RUNTIME_LIB), apple)
ADDITIONAL_OBJCFLAGS += -include GNUstep.h $(ADDITIONAL_FRAMEWORK_DIRS)
EchoServ_TOOL_LIBS = -framework netclasses $(ADDITIONAL_FRAMEWORK_DIRS)
else
EchoServ_TOOL_LIBS = -lnetclasses
endif

GUI_LIB =

include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble

