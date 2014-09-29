# Only use VMWORKS_BUILD_SHELL to wrap around bash.
# DO NOT use other shells such as zsh.
ifdef VMWORKS_BUILD_SHELL
SHELL := $(VMWORKS_BUILD_SHELL)
else
# Use bash, not whatever shell somebody has installed as /bin/sh
# This is repeated in config.mk, since envsetup.sh runs that file
# directly.
SHELL := /bin/bash
endif

# this turns off the suffix rules built into make
.SUFFIXES:

# this turns off the RCS / SCCS implicit rules of GNU Make
% : RCS/%,v
% : RCS/%
% : %,v
% : s.%
% : SCCS/s.%

# If a rule fails, delete $@.
.DELETE_ON_ERROR:

# Figure out where we are.
#TOP := $(dir $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
#TOP := $(patsubst %/,%,$(TOP))

# TOPDIR is the normal variable you should use, because
# if we are executing relative to the current directory
# it can be "", whereas TOP must be "." which causes
# pattern matching probles when make strips off the
# trailing "./" from paths in various places.
#ifeq ($(TOP),.)
#TOPDIR :=
#else
#TOPDIR := $(TOP)/
#endif

# Check for broken versions of make.
# (Allow any version under Cygwin since we don't actually build the platform there.)
ifeq (,$(findstring CYGWIN,$(shell uname -sm)))
ifneq (1,$(strip $(shell expr $(MAKE_VERSION) \>= 3.81)))
$(warning ********************************************************************************)
$(warning *  You are using version $(MAKE_VERSION) of make.)
$(warning *  vmWorks can only be built by versions 3.81 and higher.)
$(warning ********************************************************************************)
$(error stopping)
endif
endif

# Absolute path of the present working direcotry.
# This overrides the shell variable $PWD, which does not necessarily points to
# the top of the source tree, for example when "make -C" is used in m/mm/mmm.
PWD := $(shell pwd)

TOP := .
TOPDIR :=

BUILD_SYSTEM := $(TOPDIR)build/core

# This is the default target.  It must be the first declared target.
.PHONY: droid
DEFAULT_GOAL := droid
$(DEFAULT_GOAL):

# Used to force goals to build.  Only use for conditionally defined goals.
.PHONY: FORCE
FORCE:

# These goals don't need to collect and include $(VMW_MAKEFILE_NAME)/CleanSpec.mks
# in the source tree.
dont_bother_goals := clean clobber dataclean installclean help out

ifneq ($(filter $(dont_bother_goals), $(MAKECMDGOALS)),)
dont_bother := true
endif

# Targets that provide quick help on the build system.
include $(BUILD_SYSTEM)/help.mk

# Set up various standard variables based on configuration
# and host information.
include $(BUILD_SYSTEM)/config.mk

include $(BUILD_SYSTEM)/64_bit_blacklist.mk

# This allows us to force a clean build - included after the config.mk
# environment setup is done, but before we generate any dependencies.  This
# file does the rm -rf inline so the deps which are all done below will
# be generated correctly
include $(BUILD_SYSTEM)/cleanbuild.mk

VERSION_CHECK_SEQUENCE_NUMBER := 3
-include $(OUT_DIR)/versions_checked.mk
ifneq ($(VERSION_CHECK_SEQUENCE_NUMBER),$(VERSIONS_CHECKED))

$(info Checking build tools versions...)

ifneq ($(HOST_OS),windows)
ifneq ($(HOST_OS)-$(HOST_ARCH),darwin-ppc)
# check for a case sensitive file system
ifneq (a,$(shell mkdir -p $(OUT_DIR) ; \
                echo a > $(OUT_DIR)/casecheck.txt; \
                    echo B > $(OUT_DIR)/CaseCheck.txt; \
                cat $(OUT_DIR)/casecheck.txt))
$(warning ************************************************************)
$(warning You are building on a case-insensitive filesystem.)
$(warning Please move your source tree to a case-sensitive filesystem.)
$(warning ************************************************************)
$(error Case-insensitive filesystems not supported)
endif
endif
endif

# Make sure that there are no spaces in the absolute path; the
# build system can't deal with them.
ifneq ($(words $(shell pwd)),1)
$(warning ************************************************************)
$(warning You are building in a directory whose absolute path contains)
$(warning a space character:)
$(warning $(space))
$(warning "$(shell pwd)")
$(warning $(space))
$(warning Please move your source tree to a path that does not contain)
$(warning any spaces.)
$(warning ************************************************************)
$(error Directory names containing spaces not supported)
endif

$(shell echo 'VERSIONS_CHECKED := $(VERSION_CHECK_SEQUENCE_NUMBER)' \
        > $(OUT_DIR)/versions_checked.mk)
$(shell echo 'BUILD_EMULATOR ?= $(BUILD_EMULATOR)' \
        >> $(OUT_DIR)/versions_checked.mk)
endif

# These are the modifier targets that don't do anything themselves, but
# change the behavior of the build.
# (must be defined before including definitions.make)
INTERNAL_MODIFIER_TARGETS := showcommands all

# Bring in standard build system definitions.
include $(BUILD_SYSTEM)/definitions.mk

ifneq ($(filter user userdebug eng,$(MAKECMDGOALS)),)
$(info ***************************************************************)
$(info ***************************************************************)
$(info Do not pass '$(filter user userdebug eng,$(MAKECMDGOALS))' on \
       the make command line.)
$(info Set TARGET_BUILD_VARIANT in buildspec.mk, or use lunch or)
$(info choosecombo.)
$(info ***************************************************************)
$(info ***************************************************************)
$(error stopping)
endif

ifneq ($(filter-out $(INTERNAL_VALID_VARIANTS),$(TARGET_BUILD_VARIANT)),)
$(info ***************************************************************)
$(info ***************************************************************)
$(info Invalid variant: $(TARGET_BUILD_VARIANT)
$(info Valid values are: $(INTERNAL_VALID_VARIANTS)
$(info ***************************************************************)
$(info ***************************************************************)
$(error stopping)
endif

# -----------------------------------------------------------------
###
### In this section we set up the things that are different
### between the build variants
###

## user/userdebug ##

user_variant := $(filter user userdebug,$(TARGET_BUILD_VARIANT))
enable_target_debugging := true
tags_to_install :=
ifneq (,$(user_variant))
  ifeq ($(user_variant),userdebug)
    # Pick up some extra useful tools
    tags_to_install += debug
  else
    # Disable debugging in plain user builds.
    enable_target_debugging :=
  endif
else # !user_variant
endif # !user_variant

ifeq (true,$(strip $(enable_target_debugging)))
  # Target is more debuggable and adbd is on by default
  ADDITIONAL_DEFAULT_PROPERTIES += ro.debuggable=1
else # !enable_target_debugging
  # Target is less debuggable and adbd is off by default
  ADDITIONAL_DEFAULT_PROPERTIES += ro.debuggable=0
endif # !enable_target_debugging

## eng ##

ifeq ($(TARGET_BUILD_VARIANT),eng)
tags_to_install := debug eng
ifneq ($(filter ro.setupwizard.mode=ENABLED, $(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES))),)
  # Don't require the setup wizard on eng builds
  ADDITIONAL_BUILD_PROPERTIES := $(filter-out ro.setupwizard.mode=%,\
          $(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES))) \
          ro.setupwizard.mode=OPTIONAL
endif
endif


# ------------------------------------------------------------
# Define a function that, given a list of module tags, returns
# non-empty if that module should be installed in /system.

# For most goals, anything not tagged with the "tests" tag should
# be installed in /system.
define should-install-to-system
$(if $(filter tests,$(1)),,true)
endef


# If they only used the modifier goals (showcommands, etc), we'll actually
# build the default target.
ifeq ($(filter-out $(INTERNAL_MODIFIER_TARGETS),$(MAKECMDGOALS)),)
.PHONY: $(INTERNAL_MODIFIER_TARGETS)
$(INTERNAL_MODIFIER_TARGETS): $(DEFAULT_GOAL)
endif


#
# Typical build; include any $(VMW_MAKEFILE_NAME) files we can find.
#
subdirs := $(TOP)

FULL_BUILD := true


# Before we go and include all of the module makefiles, stash away
# the PRODUCT_* values so that later we can verify they are not modified.
stash_product_vars:=true
ifeq ($(stash_product_vars),true)
  $(call stash-product-vars, __STASHED)
endif

ifneq ($(ONE_SHOT_MAKEFILE),)
# We've probably been invoked by the "mm" shell function
# with a subdirectory's makefile.
include $(ONE_SHOT_MAKEFILE)
# Change CUSTOM_MODULES to include only modules that were
# defined by this makefile; this will install all of those
# modules as a side-effect.  Do this after including ONE_SHOT_MAKEFILE
# so that the modules will be installed in the same place they
# would have been with a normal make.
CUSTOM_MODULES := $(sort $(call get-tagged-modules,$(ALL_MODULE_TAGS)))
FULL_BUILD :=

# A helper goal printing out install paths
.PHONY: GET-INSTALL-PATH
GET-INSTALL-PATH:
	@$(foreach m, $(ALL_MODULES), $(if $(ALL_MODULES.$(m).INSTALLED), \
		echo 'INSTALL-PATH: $(m) $(ALL_MODULES.$(m).INSTALLED)';))

else # ONE_SHOT_MAKEFILE

ifneq ($(dont_bother),true)
#
# Include all of the makefiles in the system
#

# Can't use first-makefiles-under here because
# --mindepth=2 makes the prunes not work.
subdir_makefiles := \
	$(shell build/tools/findleaves.py --prune=$(OUT_DIR) --prune=.repo --prune=.git $(subdirs) $(VMW_MAKEFILE_NAME))

$(foreach mk, $(subdir_makefiles), $(info including $(mk) ...)$(eval include $(mk)))

endif # dont_bother

endif # ONE_SHOT_MAKEFILE

ifeq ($(stash_product_vars),true)
  $(call assert-product-vars, __STASHED)
endif

include $(BUILD_SYSTEM)/legacy_prebuilts.mk
ifneq ($(filter-out $(GRANDFATHERED_ALL_PREBUILT),$(strip $(notdir $(ALL_PREBUILT)))),)
  $(warning *** Some files have been added to ALL_PREBUILT.)
  $(warning *)
  $(warning * ALL_PREBUILT is a deprecated mechanism that)
  $(warning * should not be used for new files.)
  $(warning * As an alternative, use PRODUCT_COPY_FILES in)
  $(warning * the appropriate product definition.)
  $(warning * build/target/product/core.mk is the product)
  $(warning * definition used in all products.)
  $(warning *)
  $(foreach bad_prebuilt,$(filter-out $(GRANDFATHERED_ALL_PREBUILT),$(strip $(notdir $(ALL_PREBUILT)))),$(warning * unexpected $(bad_prebuilt) in ALL_PREBUILT))
  $(warning *)
  $(error ALL_PREBUILT contains unexpected files)
endif

# -------------------------------------------------------------------
# All module makefiles have been included at this point.
# -------------------------------------------------------------------


# -------------------------------------------------------------------
# Fix up CUSTOM_MODULES to refer to installed files rather than
# just bare module names.  Leave unknown modules alone in case
# they're actually full paths to a particular file.
known_custom_modules := $(filter $(ALL_MODULES),$(CUSTOM_MODULES))
unknown_custom_modules := $(filter-out $(ALL_MODULES),$(CUSTOM_MODULES))
CUSTOM_MODULES := \
	$(call module-installed-files,$(known_custom_modules)) \
	$(unknown_custom_modules)

# -------------------------------------------------------------------
# Define dependencies for modules that require other modules.
# This can only happen now, after we've read in all module makefiles.
#
# TODO: deal with the fact that a bare module name isn't
# unambiguous enough.  Maybe declare short targets like
# APPS:Quake or HOST:SHARED_LIBRARIES:libutils.
# BUG: the system image won't know to depend on modules that are
# brought in as requirements of other modules.
#
# Resolve the required module name to 32-bit or 64-bit variant.
ifeq ($(TARGET_IS_64_BIT),true)
# Get a list of corresponding 32-bit module names, if one exists.
define get-32-bit-modules
$(strip $(foreach m,$(1),\
  $(if $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).CLASS),\
    $(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX))))
endef
# Get a list of corresponding 32-bit module names, if one exists;
# otherwise return the original module name
define get-32-bit-modules-if-we-can
$(strip $(foreach m,$(1),\
  $(if $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).CLASS),\
    $(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX),
    $(m))))
endef

# If a module is built for 32-bit, the required modules must be 32-bit too;
# Otherwise if the module is an exectuable or shared library,
#   the required modules must be 64-bit;
#   otherwise we require both 64-bit and 32-bit variant, if one exists.
$(foreach m,$(ALL_MODULES),\
  $(eval r := $(ALL_MODULES.$(m).REQUIRED))\
  $(if $(r),\
    $(if $(ALL_MODULES.$(m).FOR_2ND_ARCH),\
      $(eval r_r := $(call get-32-bit-modules-if-we-can,$(r))),\
      $(if $(filter EXECUTABLES SHARED_LIBRARIES,$(ALL_MODULES.$(m).CLASS)),\
        $(eval r_r := $(r)),\
        $(eval r_r := $(r) $(call get-32-bit-modules,$(r)))\
       )\
     )\
     $(eval ALL_MODULES.$(m).REQUIRED := $(r_r))\
  )\
)
r_r :=
endif


define add-required-deps
$(1): | $(2)
endef

$(foreach m,$(ALL_MODULES), \
  $(eval r := $(ALL_MODULES.$(m).REQUIRED)) \
  $(if $(r), \
    $(eval r := $(call module-installed-files,$(r))) \
    $(eval t_m := $(filter $(TARGET_OUT_ROOT)/%, $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval h_m := $(filter $(HOST_OUT_ROOT)/%, $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval t_r := $(filter $(TARGET_OUT_ROOT)/%, $(r))) \
    $(eval h_r := $(filter $(HOST_OUT_ROOT)/%, $(r))) \
    $(eval t_m := $(filter-out $(t_r), $(t_m))) \
    $(eval h_m := $(filter-out $(h_r), $(h_m))) \
    $(if $(t_m), $(eval $(call add-required-deps, $(t_m),$(t_r)))) \
    $(if $(h_m), $(eval $(call add-required-deps, $(h_m),$(h_r)))) \
   ) \
 )

t_m :=
h_m :=
t_r :=
h_r :=

# Resolve the dependencies on shared libraries.
$(foreach m,$(TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES), \
  $(eval p := $(subst :,$(space),$(m))) \
  $(eval r := $(filter $(TARGET_OUT_ROOT)/%,$(call module-installed-files,\
    $(subst $(comma),$(space),$(lastword $(p)))))) \
  $(eval $(call add-required-deps,$(word 2,$(p)),$(r))))
$(foreach m,$(HOST_DEPENDENCIES_ON_SHARED_LIBRARIES), \
  $(eval p := $(subst :,$(space),$(m))) \
  $(eval r := $(filter $(HOST_OUT_ROOT)/%,$(call module-installed-files,\
    $(subst $(comma),$(space),$(lastword $(p)))))) \
  $(eval $(call add-required-deps,$(word 2,$(p)),$(r))))
ifdef TARGET_2ND_ARCH
$(foreach m,$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES), \
  $(eval p := $(subst :,$(space),$(m))) \
  $(eval r := $(filter $(TARGET_OUT_ROOT)/%,$(call module-installed-files,\
    $(addsuffix $(TARGET_2ND_ARCH_MODULE_SUFFIX), \
      $(subst $(comma),$(space),$(lastword $(p))))))) \
  $(eval $(call add-required-deps,$(word 2,$(p)),$(r))))
endif

m :=
r :=
p :=
add-required-deps :=

# -------------------------------------------------------------------
# Figure out our module sets.
#
# Of the modules defined by the component makefiles,
# determine what we actually want to build.

ifdef FULL_BUILD
  # The base list of modules to build for this product is specified
  # by the appropriate product definition file, which was included
  # by product_config.mk.
  product_MODULES := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES)
  # Filter out the overridden packages before doing expansion
  product_MODULES := $(filter-out $(foreach p, $(product_MODULES), \
      $(PACKAGES.$(p).OVERRIDES)), $(product_MODULES))

  # Resolve the :32 :64 module name
  modules_32 := $(patsubst %:32,%,$(filter %:32, $(product_MODULES)))
  modules_64 := $(patsubst %:64,%,$(filter %:64, $(product_MODULES)))
  modules_rest := $(filter-out %:32 %:64,$(product_MODULES))
  ifeq ($(TARGET_IS_64_BIT),true)
    product_MODULES := $(addsuffix $(TARGET_2ND_ARCH_MODULE_SUFFIX),$(modules_32))
    product_MODULES += $(modules_64)
    # For the rest we add both
    product_MODULES += $(call get-32-bit-modules, $(modules_rest))
    product_MODULES += $(modules_rest)
  else
    product_MODULES := $(modules_32) $(modules_64) $(modules_rest)
  endif

  $(call expand-required-modules,product_MODULES,$(product_MODULES))
  product_FILES := $(call module-installed-files, $(product_MODULES))
  ifeq (0,1)
    $(info product_FILES for $(TARGET_DEVICE) ($(INTERNAL_PRODUCT)):)
    $(foreach p,$(product_FILES),$(info :   $(p)))
    $(error done)
  endif
else
  # We're not doing a full build, and are probably only including
  # a subset of the module makefiles.  Don't try to build any modules
  # requested by the product, because we probably won't have rules
  # to build them.
  product_FILES :=
endif

eng_MODULES := $(sort \
        $(call get-tagged-modules,eng) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_ENG)) \
    )
debug_MODULES := $(sort \
        $(call get-tagged-modules,debug) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_DEBUG)) \
    )
tests_MODULES := $(sort \
        $(call get-tagged-modules,tests) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_TESTS)) \
    )

# TODO: Remove the 3 places in the tree that use ALL_DEFAULT_INSTALLED_MODULES
# and get rid of it from this list.
modules_to_install := $(sort \
    $(ALL_DEFAULT_INSTALLED_MODULES) \
    $(product_FILES) \
    $(foreach tag,$(tags_to_install),$($(tag)_MODULES)) \
    $(CUSTOM_MODULES) \
  )

# Some packages may override others using LOCAL_OVERRIDES_PACKAGES.
# Filter out (do not install) any overridden packages.
overridden_packages := $(call get-package-overrides,$(modules_to_install))
ifdef overridden_packages
#  old_modules_to_install := $(modules_to_install)
  modules_to_install := \
      $(filter-out $(foreach p,$(overridden_packages),$(p) %/$(p).apk), \
          $(modules_to_install))
endif
#$(error filtered out
#           $(filter-out $(modules_to_install),$(old_modules_to_install)))


# build/core/Makefile contains extra stuff that we don't want to pollute this
# top-level makefile with.  It expects that ALL_DEFAULT_INSTALLED_MODULES
# contains everything that's built during the current make, but it also further
# extends ALL_DEFAULT_INSTALLED_MODULES.
ALL_DEFAULT_INSTALLED_MODULES := $(modules_to_install)
include $(BUILD_SYSTEM)/Makefile
modules_to_install := $(sort $(ALL_DEFAULT_INSTALLED_MODULES))
ALL_DEFAULT_INSTALLED_MODULES :=


# These are additional goals that we build, in order to make sure that there
# is as little code as possible in the tree that doesn't build.
modules_to_check := $(foreach m,$(ALL_MODULES),$(ALL_MODULES.$(m).CHECKED))

# If you would like to build all goals, and not skip any intermediate
# steps, you can pass the "all" modifier goal on the commandline.
ifneq ($(filter all,$(MAKECMDGOALS)),)
modules_to_check += $(foreach m,$(ALL_MODULES),$(ALL_MODULES.$(m).BUILT))
endif

# for easier debugging
modules_to_check := $(sort $(modules_to_check))
#$(error modules_to_check $(modules_to_check))

# -------------------------------------------------------------------
# This is used to to get the ordering right, you can also use these,
# but they're considered undocumented, so don't complain if their
# behavior changes.
.PHONY: prebuilt
prebuilt: $(ALL_PREBUILT)

# An internal target that depends on all copied headers
# (see copy_headers.make).  Other targets that need the
# headers to be copied first can depend on this target.
.PHONY: all_copied_headers
all_copied_headers: ;

$(ALL_C_CPP_ETC_OBJECTS): | all_copied_headers

# All the droid stuff, in directories
.PHONY: files
files: prebuilt \
        $(modules_to_install) \
        $(INSTALLED_VMWORKS_INFO_TXT_TARGET)

# -------------------------------------------------------------------

.PHONY: checkbuild
checkbuild: $(modules_to_check)
ifeq (true,$(VMWORKS_BUILD_EVERYTHING_BY_DEFAULT)$(filter $(MAKECMDGOALS),checkbuild))
droid: checkbuild
else
# VMWORKS_BUILD_EVERYTHING_BY_DEFAULT not set, or checkbuild is one of the cmd goals.
checkbuild: droid
endif

.PHONY: ramdisk
ramdisk: $(INSTALLED_RAMDISK_TARGET)

.PHONY: userdataimage
userdataimage: $(INSTALLED_USERDATAIMAGE_TARGET)

ifneq (,$(filter userdataimage, $(MAKECMDGOALS)))
$(call dist-for-goals, userdataimage, $(BUILT_USERDATAIMAGE_TARGET))
endif

.PHONY: bootimage
bootimage: $(INSTALLED_BOOTIMAGE_TARGET)

# phony target that include any targets in $(ALL_MODULES)
.PHONY: all_modules
ifndef BUILD_MODULES_IN_PATHS
all_modules: $(ALL_MODULES)
else
# BUILD_MODULES_IN_PATHS is a list of paths relative to the top of the tree
module_path_patterns := $(foreach p, $(BUILD_MODULES_IN_PATHS),\
    $(if $(filter %/,$(p)),$(p)%,$(p)/%))
my_all_modules := $(sort $(foreach m, $(ALL_MODULES),$(if $(filter\
    $(module_path_patterns), $(addsuffix /,$(ALL_MODULES.$(m).PATH))),$(m))))
all_modules: $(my_all_modules)
endif


# Build files and then package it into the rom formats
.PHONY: droidcore
droidcore: files \
	systemimage \
	$(INSTALLED_BOOTIMAGE_TARGET) \
	$(INSTALLED_USERDATAIMAGE_TARGET) \
	$(INSTALLED_FILES_FILE)

# dist_files only for putting your library into the dist directory with a full build.
.PHONY: dist_files

$(call dist-for-goals, droidcore,		\
  $(SYMBOLS_ZIP)						\
  $(INSTALLED_FILES_FILE)				\
  $(INSTALLED_BUILD_PROP_TARGET)		\
  $(BUILT_TARGET_FILES_PACKAGE)			\
  $(INSTALLED_VMWORKS_INFO_TXT_TARGET)	\
  $(INSTALLED_RAMDISK_TARGET)			\
 )

# Put a copy of the radio/bootloader files in the dist dir.
$(foreach f,$(INSTALLED_RADIOIMAGE_TARGET), \
  $(call dist-for-goals, droidcore, $(f)))

ifneq ($(TARGET_BUILD_PDK),true)
  $(call dist-for-goals, droidcore, \
    $(APPS_ZIP) \
    $(INTERNAL_EMULATOR_PACKAGE_TARGET) \
    $(PACKAGE_STATS_FILE) \
  )
endif


# Building a full system-- the default is to build droidcore
droid: droidcore dist_files


.PHONY: clean
clean:
	@rm -rf $(OUT_DIR)
	@echo "Entire build directory removed."

# The rules for dataclean and installclean are defined in cleanbuild.mk.

#xxx scrape this from ALL_MODULE_NAME_TAGS
.PHONY: modules
modules:
	@echo "Available sub-modules:"
	@echo "$(call module-names-for-tag-list,$(ALL_MODULE_TAGS))" | \
	      tr -s ' ' '\n' | sort -u | $(COLUMN)

.PHONY: showcommands
showcommands:
	@echo >/dev/null

.PHONY: nothing
nothing:
	@echo Successfully read the makefiles.
