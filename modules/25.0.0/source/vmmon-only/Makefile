#!/usr/bin/make -f
##########################################################
# Copyright (C) 1998-2020 VMware, Inc. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation version 2 and no later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#
##########################################################

####
####  VMware kernel module Makefile to be distributed externally
####

####
#### SRCROOT _must_ be a relative path.
####
SRCROOT = .

#
# Auto-detect kernel compiler and linker
# This is needed for kernels built with Clang/LLVM (common in custom kernels)
# Make has CC=cc by default, so we check if it hasn't been explicitly overridden
#
ifeq ($(origin CC),default)
KERNEL_CC := $(shell cat /proc/version 2>/dev/null | grep -o -E '(gcc|clang) version' | awk '{print $$1}' | head -1)
ifeq ($(KERNEL_CC),clang)
  # Kernel was built with Clang, use Clang for modules
  ifneq ($(shell command -v clang 2>/dev/null),)
    override CC := clang
    $(info Auto-detected Clang kernel - using CC=clang)
    export CC

    # Also need LLVM linker for Clang-built kernels with LTO
    ifeq ($(origin LD),default)
      ifneq ($(shell command -v ld.lld 2>/dev/null),)
        override LD := ld.lld
        $(info Auto-detected LLVM linker - using LD=ld.lld)
        export LD
      endif
    endif
  endif
endif
endif

#
# open-vm-tools doesn't replicate shared source files for different modules;
# instead, files are kept in shared locations. So define a few useful macros
# to be able to handle both cases cleanly.
#
INCLUDE      :=
ifdef OVT_SOURCE_DIR
VMLIB_PATH   = $(OVT_SOURCE_DIR)/lib/$(1)
INCLUDE      += -I$(OVT_SOURCE_DIR)/modules/linux/shared
INCLUDE      += -I$(OVT_SOURCE_DIR)/lib/include
else
INCLUDE      += -I$(SRCROOT)/shared
endif


VM_UNAME = $(shell uname -r)

# Header directory for the running kernel
ifdef LINUXINCLUDE
HEADER_DIR = $(LINUXINCLUDE)
else
HEADER_DIR = /lib/modules/$(VM_UNAME)/build/include
endif

BUILD_DIR = $(HEADER_DIR)/..

DRIVER := vmmon
PRODUCT := @@PRODUCT@@

# Grep program
GREP = /bin/grep

vm_check_gcc = $(shell if $(CC) $(1) -S -o /dev/null -xc /dev/null \
        > /dev/null 2>&1; then echo "$(1)"; else echo "$(2)"; fi)
vm_check_file = $(shell if test -f $(1); then echo "yes"; else echo "no"; fi)
vm_check_dir = $(shell if test -d $(1); then echo "yes"; else echo "no"; fi)

ifndef VM_KBUILD
VM_KBUILD := no
ifeq ($(call vm_check_file,$(BUILD_DIR)/Makefile), yes)
VM_KBUILD := yes
endif
export VM_KBUILD
endif

ifndef VM_KBUILD_SHOWN
ifeq ($(VM_KBUILD), no)
VM_DUMMY := $(shell echo >&2 "Using standalone build system.")
else
VM_DUMMY := $(shell echo >&2 "Using kernel build system.")
endif
VM_KBUILD_SHOWN := yes
export VM_KBUILD_SHOWN
endif

ifneq ($(VM_KBUILD), no)

# If there is no version defined, we are in toplevel pass, not yet in kernel makefiles...
ifeq ($(VERSION),)

DRIVER_KO := $(DRIVER).ko

.PHONY: $(DRIVER_KO)

auto-build: $(DRIVER_KO)
	cp -f $< $(SRCROOT)/../$(DRIVER).o

# $(DRIVER_KO) is a phony target, so compare file times explicitly
$(DRIVER): $(DRIVER_KO)
	if [ $< -nt $@ ] || [ ! -e $@ ] ; then cp -f $< $@; fi

# Use SUBDIRS on 2.x, 3.x, 4.x.  Use M on newer kernels.
ifeq ($(filter-out 2 3 4,$(firstword $(subst ., ,$(VM_UNAME)))),)
DIRVAR := SUBDIRS
else
DIRVAR := M
endif

#
# It seems that some distros do weird things with kernel headers:
# try to figure out the proper header placement
ifeq ($(call vm_check_dir,$(HEADER_DIR)/linux), yes)
KERNEL_HEADER_DIR := $(HEADER_DIR)
else
KERNEL_HEADER_DIR := /lib/modules/$(VM_UNAME)/source/include
endif

ifeq ($(call vm_check_dir,$(KERNEL_HEADER_DIR)/linux), no)
$(warning ---------------------------------------------------------)
$(warning The kernel header directory seems invalid)
$(warning Tried: $(KERNEL_HEADER_DIR) and $(HEADER_DIR))
$(warning Please make sure linux kernel headers are installed)
$(warning Alternatively set LINUXINCLUDE to point to the correct path)
$(warning ---------------------------------------------------------)
endif

#
# Trivial define to check whether a given header has a given function
# and if so report it as missing in the passed name:
# Args:
#     $(1) - kernel header file
#     $(2) - string to grep for
#     $(3) - the define name to use as a missing arg
check_func = "-D$(3)=$(shell grep $(2) \
	$(KERNEL_HEADER_DIR)/$(1) >/dev/null 2>&1; echo $$?) "

VMW_CFLAGS := $(call check_func,linux/timer.h,"int timer_delete_sync",TIMER_DELETE_SYNC_MISSING)

#
# Define a setup target that gets built before the actual driver.
# This target may not be used at all, but if it is then it will be defined
# in Makefile.kernel
#
prebuild:: ;
postbuild:: ;

$(DRIVER_KO): prebuild
	$(MAKE) -C $(BUILD_DIR) $(DIRVAR)=$$PWD SRCROOT=$$PWD/$(SRCROOT) \
	  $(if $(CC),CC=$(CC)) $(if $(LD),LD=$(LD)) \
	  VMW_CFLAGS=$(VMW_CFLAGS) MODULEBUILDDIR=$(MODULEBUILDDIR) V=1 modules
	$(MAKE) -C $$PWD SRCROOT=$$PWD/$(SRCROOT) \
	  MODULEBUILDDIR=$(MODULEBUILDDIR) postbuild
endif

vm_check_build = $(shell if $(CC) $(KBUILD_CPPFLAGS) $(KBUILD_CFLAGS) \
	$(CPPFLAGS) $(CFLAGS) $(CFLAGS_KERNEL) $(LINUXINCLUDE) \
	$(EXTRA_CFLAGS) -Iinclude2/asm/mach-default \
	-DKBUILD_BASENAME=\"$(DRIVER)\" \
	-Werror -S -o /dev/null -xc $(1) \
	> /dev/null 2>&1; then echo "$(2)"; else echo "$(3)"; fi)

CC_WARNINGS := -Wall -Wstrict-prototypes
CC_OPTS := $(GLOBAL_DEFS) $(CC_WARNINGS) -DVMW_USING_KBUILD
ifdef VMX86_DEVEL
CC_OPTS += -DVMX86_DEVEL
endif
ifdef VMX86_DEBUG
CC_OPTS += -DVMX86_DEBUG
endif

# Add Spectre options when available

include $(SRCROOT)/Makefile.kernel

else

include $(SRCROOT)/Makefile.normal

endif

#.SILENT:
