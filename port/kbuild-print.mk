# Evaluates one Linux Kbuild Makefile with config.mk and prints variables.
#   make -s -f kbuild-print.mk LINUX=<tree> DIR=<dir in tree> VARS="<vars>"
include $(dir $(lastword $(MAKEFILE_LIST)))config.mk
srctree := $(LINUX)
src := $(LINUX)/$(DIR)
obj := $(DIR)
cc-option = $(1)
cc-disable-warning =
cc-ifversion =
include $(src)/Makefile
.PHONY: print
print:
	@$(foreach v,$(VARS),echo "$(v)=$($(v))";)
