# Users can define base-rules-hook in their buildspec.mk to perform
# arbitrary operations as each module is included.
ifdef base-rules-hook
$(if $(base-rules-hook),)
endif

###########################################################
## Common instructions for a generic module.
###########################################################

LOCAL_MODULE := $(strip $(LOCAL_MODULE))
ifeq ($(LOCAL_MODULE),)
  $(error $(LOCAL_PATH): LOCAL_MODULE is not defined)
endif

LOCAL_IS_HOST_MODULE := $(strip $(LOCAL_IS_HOST_MODULE))
ifdef LOCAL_IS_HOST_MODULE
  ifneq ($(LOCAL_IS_HOST_MODULE),true)
    $(error $(LOCAL_PATH): LOCAL_IS_HOST_MODULE must be "true" or empty, not "$(LOCAL_IS_HOST_MODULE)")
  endif
  my_prefix := HOST_
  my_host := host-
else
  my_prefix := TARGET_
  my_host :=
endif

my_module_tags := $(LOCAL_MODULE_TAGS)

###########################################################
## Validate and define fallbacks for input LOCAL_* variables.
###########################################################

## Dump a .csv file of all modules and their tags
#ifneq ($(tag-list-first-time),false)
#$(shell rm -f tag-list.csv)
#tag-list-first-time := false
#endif
#$(shell echo $(lastword $(filter-out config/% out/%,$(MAKEFILE_LIST))),$(LOCAL_MODULE),$(strip $(LOCAL_MODULE_CLASS)),$(subst $(space),$(comma),$(sort $(my_module_tags))) >> tag-list.csv)

LOCAL_UNINSTALLABLE_MODULE := $(strip $(LOCAL_UNINSTALLABLE_MODULE))
my_module_tags := $(sort $(my_module_tags))
ifeq (,$(my_module_tags))
  my_module_tags := optional
endif

# User tags are not allowed anymore.  Fail early because it will not be installed
# like it used to be.
ifneq ($(filter $(my_module_tags),user),)
  $(warning *** Module name: $(LOCAL_MODULE))
  $(warning *** Makefile location: $(LOCAL_MODULE_MAKEFILE))
  $(warning * )
  $(warning * Module is attempting to use the 'user' tag.  This)
  $(warning * used to cause the module to be installed automatically.)
  $(warning * Now, the module must be listed in the PRODUCT_PACKAGES)
  $(warning * section of a product makefile to have it installed.)
  $(warning * )
  $(error user tag detected on module.)
endif

# Only the tags mentioned in this test are expected to be set by module
# makefiles. Anything else is either a typo or a source of unexpected
# behaviors.
ifneq ($(filter-out debug eng tests optional samples,$(my_module_tags)),)
$(warning unusual tags $(my_module_tags) on $(LOCAL_MODULE) at $(LOCAL_PATH))
endif

# Add implicit tags.
#
# If the local directory or one of its parents contains a MODULE_LICENSE_GPL
# file, tag the module as "gnu".  Search for "*_GPL*" and "*_MPL*" so that we can also
# find files like MODULE_LICENSE_GPL_AND_AFL but exclude files like
# MODULE_LICENSE_LGPL.
#
gpl_license_file := $(call find-parent-file,$(LOCAL_PATH),MODULE_LICENSE*_GPL* MODULE_LICENSE*_MPL*)
ifneq ($(gpl_license_file),)
  my_module_tags += gnu
  ALL_GPL_MODULE_LICENSE_FILES := $(sort $(ALL_GPL_MODULE_LICENSE_FILES) $(gpl_license_file))
endif

LOCAL_MODULE_CLASS := $(strip $(LOCAL_MODULE_CLASS))
ifneq ($(words $(LOCAL_MODULE_CLASS)),1)
  $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS must contain exactly one word, not "$(LOCAL_MODULE_CLASS)")
endif

ifndef LOCAL_IS_HOST_MODULE
my_32_64_bit_suffix := $(if $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_IS_64_BIT),64,32)
endif

ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
ifndef LOCAL_IS_HOST_MODULE
my_multilib_module_path := $(strip $(LOCAL_MODULE_PATH_$(my_32_64_bit_suffix)))
else
my_multilib_module_path :=
endif
ifdef my_multilib_module_path
my_module_path := $(my_multilib_module_path)
else
my_module_path := $(strip $(LOCAL_MODULE_PATH))
endif
my_module_relative_path := $(strip $(LOCAL_MODULE_RELATIVE_PATH))
ifeq ($(my_module_path),)
  ifdef LOCAL_IS_HOST_MODULE
    partition_tag :=
  else
  ifeq (true,$(LOCAL_PROPRIETARY_MODULE))
    partition_tag := _VENDOR
  else
    # The definition of should-install-to-system will be different depending
    # on which goal (e.g., sdk or just droid) is being built.
    partition_tag := $(if $(call should-install-to-system,$(my_module_tags)),,_DATA)
  endif
  endif
  install_path_var := $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT$(partition_tag)_$(LOCAL_MODULE_CLASS)
  ifeq (true,$(LOCAL_PRIVILEGED_MODULE))
    install_path_var := $(install_path_var)_PRIVILEGED
  endif

  my_module_path := $($(install_path_var))
  ifeq ($(strip $(my_module_path)),)
    $(error $(LOCAL_PATH): unhandled install path "$(install_path_var) for $(LOCAL_MODULE)")
  endif
endif
ifneq ($(my_module_relative_path),)
  my_module_path := $(my_module_path)/$(my_module_relative_path)
endif
endif # not LOCAL_UNINSTALLABLE_MODULE

ifneq ($(strip $(LOCAL_BUILT_MODULE)$(LOCAL_INSTALLED_MODULE)),)
  $(error $(LOCAL_PATH): LOCAL_BUILT_MODULE and LOCAL_INSTALLED_MODULE must not be defined by component makefiles)
endif

my_register_name := $(LOCAL_MODULE)
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
ifndef LOCAL_NO_2ND_ARCH_MODULE_SUFFIX
my_register_name := $(LOCAL_MODULE)$(TARGET_2ND_ARCH_MODULE_SUFFIX)
endif
endif
# Make sure that this IS_HOST/CLASS/MODULE combination is unique.
module_id := MODULE.$(if \
    $(LOCAL_IS_HOST_MODULE),HOST,TARGET).$(LOCAL_MODULE_CLASS).$(my_register_name)
ifdef $(module_id)
$(error $(LOCAL_PATH): $(module_id) already defined by $($(module_id)))
endif
$(module_id) := $(LOCAL_PATH)

intermediates := $(call local-intermediates-dir,,$(LOCAL_2ND_ARCH_VAR_PREFIX))
intermediates.COMMON := $(call local-intermediates-dir,COMMON)
generated_sources_dir := $(call local-generated-sources-dir)

###########################################################
# Pick a name for the intermediate and final targets
###########################################################
include $(BUILD_SYSTEM)/configure_module_stem.mk

# OVERRIDE_BUILT_MODULE_PATH is only allowed to be used by the
# internal SHARED_LIBRARIES build files.
OVERRIDE_BUILT_MODULE_PATH := $(strip $(OVERRIDE_BUILT_MODULE_PATH))
ifdef OVERRIDE_BUILT_MODULE_PATH
  ifneq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
    $(error $(LOCAL_PATH): Illegal use of OVERRIDE_BUILT_MODULE_PATH)
  endif
  built_module_path := $(OVERRIDE_BUILT_MODULE_PATH)
else
  built_module_path := $(intermediates)
endif
LOCAL_BUILT_MODULE := $(built_module_path)/$(LOCAL_BUILT_MODULE_STEM)
built_module_path :=

ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
  LOCAL_INSTALLED_MODULE := $(my_module_path)/$(LOCAL_INSTALLED_MODULE_STEM)
endif

# Assemble the list of targets to create PRIVATE_ variables for.
LOCAL_INTERMEDIATE_TARGETS += $(LOCAL_BUILT_MODULE)


###########################################################
## make clean- targets
###########################################################
cleantarget := clean-$(my_register_name)
$(cleantarget) : PRIVATE_MODULE := $(my_register_name)
$(cleantarget) : PRIVATE_CLEAN_FILES := \
    $(LOCAL_BUILT_MODULE) \
    $(LOCAL_INSTALLED_MODULE) \
    $(intermediates)
$(cleantarget)::
	@echo "Clean: $(PRIVATE_MODULE)"
	$(hide) rm -rf $(PRIVATE_CLEAN_FILES)


# Propagate local configuration options to this target.
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_PATH:=$(LOCAL_PATH)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_IS_HOST_MODULE := $(LOCAL_IS_HOST_MODULE)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_HOST:= $(my_host)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_INTERMEDIATES_DIR:= $(intermediates)

# Tell the module and all of its sub-modules who it is.
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_MODULE:= $(my_register_name)

# Provide a short-hand for building this module.
# We name both BUILT and INSTALLED in case
# LOCAL_UNINSTALLABLE_MODULE is set.
.PHONY: $(my_register_name)
$(my_register_name): $(LOCAL_BUILT_MODULE) $(LOCAL_INSTALLED_MODULE)

###########################################################
## Module installation rule
###########################################################

# Some hosts do not have ACP; override the LOCAL version if that's the case.
ifneq ($(strip $(HOST_ACP_UNAVAILABLE)),)
  LOCAL_ACP_UNAVAILABLE := $(strip $(HOST_ACP_UNAVAILABLE))
endif

ifndef LOCAL_UNINSTALLABLE_MODULE
  # Define a copy rule to install the module.
  # acp and libraries that it uses can't use acp for
  # installation;  hence, LOCAL_ACP_UNAVAILABLE.
$(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := $(LOCAL_POST_INSTALL_CMD)
ifneq ($(LOCAL_ACP_UNAVAILABLE),true)
$(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE) | $(ACP)
	@echo "Install: $@"
	$(copy-file-to-new-target)
	$(PRIVATE_POST_INSTALL_CMD)
else
$(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE)
	@echo "Install: $@"
	$(copy-file-to-target-with-cp)
endif

endif # !LOCAL_UNINSTALLABLE_MODULE


###########################################################
## CHECK_BUILD goals
###########################################################

# If nobody has defined a more specific module for the
# checked modules, use LOCAL_BUILT_MODULE.
ifndef LOCAL_CHECKED_MODULE
  LOCAL_CHECKED_MODULE := $(LOCAL_BUILT_MODULE)
endif

# If they request that this module not be checked, then don't.
# PLEASE DON'T SET THIS.  ANY PLACES THAT SET THIS WITHOUT
# GOOD REASON WILL HAVE IT REMOVED.
ifdef LOCAL_DONT_CHECK_MODULE
  LOCAL_CHECKED_MODULE :=
endif
# Don't check build the module defined for the 2nd arch
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
  LOCAL_CHECKED_MODULE :=
endif

###########################################################
## Register with ALL_MODULES
###########################################################

ALL_MODULES += $(my_register_name)

# Don't use += on subvars, or else they'll end up being
# recursively expanded.
ALL_MODULES.$(my_register_name).CLASS := \
    $(ALL_MODULES.$(my_register_name).CLASS) $(LOCAL_MODULE_CLASS)
ALL_MODULES.$(my_register_name).PATH := \
    $(ALL_MODULES.$(my_register_name).PATH) $(LOCAL_PATH)
ALL_MODULES.$(my_register_name).TAGS := \
    $(ALL_MODULES.$(my_register_name).TAGS) $(my_module_tags)
ALL_MODULES.$(my_register_name).CHECKED := \
    $(ALL_MODULES.$(my_register_name).CHECKED) $(LOCAL_CHECKED_MODULE)
ALL_MODULES.$(my_register_name).BUILT := \
    $(ALL_MODULES.$(my_register_name).BUILT) $(LOCAL_BUILT_MODULE)
ALL_MODULES.$(my_register_name).INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).INSTALLED) $(LOCAL_INSTALLED_MODULE))
ALL_MODULES.$(my_register_name).REQUIRED := \
    $(strip $(ALL_MODULES.$(my_register_name).REQUIRED) $(LOCAL_REQUIRED_MODULES) \
      $(LOCAL_REQUIRED_MODULES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)))
ALL_MODULES.$(my_register_name).EVENT_LOG_TAGS := \
    $(ALL_MODULES.$(my_register_name).EVENT_LOG_TAGS) $(event_log_tags)
ALL_MODULES.$(my_register_name).INTERMEDIATE_SOURCE_DIR := \
    $(ALL_MODULES.$(my_register_name).INTERMEDIATE_SOURCE_DIR) $(LOCAL_INTERMEDIATE_SOURCE_DIR)
ALL_MODULES.$(my_register_name).MAKEFILE := \
    $(ALL_MODULES.$(my_register_name).MAKEFILE) $(LOCAL_MODULE_MAKEFILE)
ifdef LOCAL_MODULE_OWNER
ALL_MODULES.$(my_register_name).OWNER := \
    $(sort $(ALL_MODULES.$(my_register_name).OWNER) $(LOCAL_MODULE_OWNER))
endif
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
ALL_MODULES.$(my_register_name).FOR_2ND_ARCH := true
endif

INSTALLABLE_FILES.$(LOCAL_INSTALLED_MODULE).MODULE := $(my_register_name)

###########################################################
## Take care of my_module_tags
###########################################################

# Keep track of all the tags we've seen.
ALL_MODULE_TAGS := $(sort $(ALL_MODULE_TAGS) $(my_module_tags))

# Add this module to the tag list of each specified tag.
# Don't use "+=". If the variable hasn't been set with ":=",
# it will default to recursive expansion.
$(foreach tag,$(my_module_tags),\
    $(eval ALL_MODULE_TAGS.$(tag) := \
        $(ALL_MODULE_TAGS.$(tag)) \
        $(LOCAL_INSTALLED_MODULE)))

# Add this module name to the tag list of each specified tag.
$(foreach tag,$(my_module_tags),\
    $(eval ALL_MODULE_NAME_TAGS.$(tag) += $(my_register_name)))

###########################################################
## umbrella targets used to verify builds
###########################################################
j_or_n :=
ifneq (,$(filter EXECUTABLES SHARED_LIBRARIES STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS)))
j_or_n := native
endif
ifdef LOCAL_IS_HOST_MODULE
h_or_t := host
else
h_or_t := target
endif

ifdef j_or_n
$(j_or_n) $(h_or_t) $(j_or_n)-$(h_or_t) : $(LOCAL_CHECKED_MODULE)
ifneq (,$(filter $(my_module_tags),tests))
$(j_or_n)-$(h_or_t)-tests $(j_or_n)-tests $(h_or_t)-tests : $(LOCAL_CHECKED_MODULE)
endif
endif


#:vi noexpandtab
