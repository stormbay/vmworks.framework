###########################################################
## Standard rules for building binary object files from
## asm/c/cpp/yacc/lex/etc source files.
##
## The list of object files is exported in $(all_objects).
###########################################################

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################


##################################################
# Compute the dependency of the shared libraries
##################################################
# On the target, we compile with -nostdlib, so we must add in the
# default system shared libraries, unless they have requested not
# to by supplying a LOCAL_SYSTEM_SHARED_LIBRARIES value.  One would
# supply that, for example, when building libc itself.
ifdef LOCAL_IS_HOST_MODULE
  ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
      my_system_shared_libraries :=
  else
      my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
  endif
else
  ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
      my_system_shared_libraries := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_DEFAULT_SYSTEM_SHARED_LIBRARIES)
  else
      my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
  endif
endif

# The following LOCAL_ variables will be modified in this file.
# Because the same LOCAL_ variables may be used to define modules for both 1st arch and 2nd arch,
# we can't modify them in place.
my_src_files := $(LOCAL_SRC_FILES)
my_static_libraries := $(LOCAL_STATIC_LIBRARIES)
my_whole_static_libraries := $(LOCAL_WHOLE_STATIC_LIBRARIES)
my_shared_libraries := $(LOCAL_SHARED_LIBRARIES)
my_cflags := $(LOCAL_CFLAGS)
my_cppflags := $(LOCAL_CPPFLAGS)
my_ldflags := $(LOCAL_LDFLAGS)
my_asflags := $(LOCAL_ASFLAGS)
my_cc := $(LOCAL_CC)
my_cxx := $(LOCAL_CXX)
my_c_includes := $(LOCAL_C_INCLUDES)
my_generated_sources := $(LOCAL_GENERATED_SOURCES)

ifndef LOCAL_IS_HOST_MODULE
my_src_files += $(LOCAL_SRC_FILES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_SRC_FILES_$(my_32_64_bit_suffix))
my_shared_libraries += $(LOCAL_SHARED_LIBRARIES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_SHARED_LIBRARIES_$(my_32_64_bit_suffix))
my_cflags += $(LOCAL_CFLAGS_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CFLAGS_$(my_32_64_bit_suffix))
my_cppflags += $(LOCAL_CPPFLAGS_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CPPFLAGS_$(my_32_64_bit_suffix))
my_ldflags += $(LOCAL_LDFLAGS_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_LDFLAGS_$(my_32_64_bit_suffix))
my_asflags += $(LOCAL_ASFLAGS_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_ASFLAGS_$(my_32_64_bit_suffix))
my_c_includes += $(LOCAL_C_INCLUDES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_C_INCLUDES_$(my_32_64_bit_suffix))
my_generated_sources += $(LOCAL_GENERATED_SOURCES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_GENERATED_SOURCES_$(my_32_64_bit_suffix))

# arch-specific static libraries go first so that generic ones can depend on them
my_static_libraries := $(LOCAL_STATIC_LIBRARIES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_STATIC_LIBRARIES_$(my_32_64_bit_suffix)) $(my_static_libraries)
my_whole_static_libraries := $(LOCAL_WHOLE_STATIC_LIBRARIES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_WHOLE_STATIC_LIBRARIES_$(my_32_64_bit_suffix)) $(my_whole_static_libraries)

my_cflags := $(filter-out $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_UNSUPPORTED_CFLAGS),$(my_cflags))
endif

# Add static HAL libraries
ifdef LOCAL_HAL_STATIC_LIBRARIES
$(foreach lib, $(LOCAL_HAL_STATIC_LIBRARIES), \
    $(eval b_lib := $(filter $(lib).%,$(BOARD_HAL_STATIC_LIBRARIES)))\
    $(if $(b_lib), $(eval my_static_libraries += $(b_lib)),\
                   $(eval my_static_libraries += $(lib).default)))
b_lib :=
endif

ifeq ($(strip $(LOCAL_ADDRESS_SANITIZER)),true)
  LOCAL_CLANG := true
  my_cflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_CFLAGS)
  my_ldflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_LDFLAGS)
  my_shared_libraries += $(ADDRESS_SANITIZER_CONFIG_EXTRA_SHARED_LIBRARIES)
  my_static_libraries += $(ADDRESS_SANITIZER_CONFIG_EXTRA_STATIC_LIBRARIES)
endif

ifeq ($(strip $($(LOCAL_2ND_ARCH_VAR_PREFIX)WITHOUT_$(my_prefix)CLANG)),true)
  LOCAL_CLANG :=
endif

# Add in libcompiler_rt for all regular device builds
ifeq (,$(LOCAL_IS_HOST_MODULE)$(WITHOUT_LIBCOMPILER_RT))
  my_static_libraries += $(COMPILER_RT_CONFIG_EXTRA_STATIC_LIBRARIES)
endif

my_compiler_dependencies :=
ifeq ($(strip $(LOCAL_CLANG)),true)
  my_compiler_dependencies := $(CLANG) $(CLANG_CXX)
endif

####################################################
## Add FDO flags if FDO is turned on and supported
####################################################
ifneq ($(strip $(LOCAL_FDO_SUPPORT)),)
  ifeq ($(strip $(LOCAL_IS_HOST_MODULE)),)
    my_cflags += $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_FDO_CFLAGS)
    my_cppflags += $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_FDO_CFLAGS)
    my_ldflags += $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_FDO_CFLAGS)
  endif
endif

###########################################################
## Explicitly declare assembly-only __ASSEMBLY__ macro for
## assembly source
###########################################################
my_asflags += -D__ASSEMBLY__


##########################################################
## Set up installed module dependency
## We cannot compute the full path of the LOCAL_SHARED_LIBRARIES for
## they may cusomize their install path with LOCAL_MODULE_PATH
##########################################################
# Get the list of INSTALLED libraries as module names.
installed_shared_library_module_names := \
      $(my_system_shared_libraries) $(my_shared_libraries)
installed_shared_library_module_names := $(sort $(installed_shared_library_module_names))

# The real dependency will be added after all $(VMW_MAKEFILE_NAME) are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
ifdef installed_shared_library_module_names
$(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
    $(LOCAL_MODULE):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(installed_shared_library_module_names))
endif
endif

###########################################################
## Define PRIVATE_ variables from global vars
###########################################################
ifndef LOCAL_IS_HOST_MODULE
my_target_project_includes := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_PROJECT_INCLUDES)
my_target_c_includes := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_C_INCLUDES)
my_target_global_cppflags :=

ifeq ($(LOCAL_CLANG),true)
my_target_global_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_TARGET_GLOBAL_CFLAGS)
my_target_global_cppflags += $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_TARGET_GLOBAL_CPPFLAGS)
my_target_global_ldflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_TARGET_GLOBAL_LDFLAGS)
my_target_c_includes += $(CLANG_CONFIG_EXTRA_TARGET_C_INCLUDES)
else
my_target_global_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CFLAGS)
my_target_global_cppflags += $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CPPFLAGS)
my_target_global_ldflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_LDFLAGS)
endif # LOCAL_CLANG

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_PROJECT_INCLUDES := $(my_target_project_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_C_INCLUDES := $(my_target_c_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_GLOBAL_CFLAGS := $(my_target_global_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_GLOBAL_CPPFLAGS := $(my_target_global_cppflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_GLOBAL_LDFLAGS := $(my_target_global_ldflags)

else # LOCAL_IS_HOST_MODULE

ifeq ($(LOCAL_CLANG),true)
my_host_global_cflags := $(CLANG_HOST_GLOBAL_CFLAGS)
my_host_global_cppflags := $(CLANG_HOST_GLOBAL_CPPFLAGS)
my_host_global_ldflags := $(CLANG_HOST_GLOBAL_LDFLAGS)
my_host_c_includes := $(HOST_C_INCLUDES) $(CLANG_CONFIG_EXTRA_HOST_C_INCLUDES)
else
my_host_global_cflags := $(HOST_GLOBAL_CFLAGS)
my_host_global_cppflags := $(HOST_GLOBAL_CPPFLAGS)
my_host_global_ldflags := $(HOST_GLOBAL_LDFLAGS)
my_host_c_includes := $(HOST_C_INCLUDES)
endif # LOCAL_CLANG

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HOST_C_INCLUDES := $(my_host_c_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HOST_GLOBAL_CFLAGS := $(my_host_global_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HOST_GLOBAL_CPPFLAGS := $(my_host_global_cppflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HOST_GLOBAL_LDFLAGS := $(my_host_global_ldflags)
endif # LOCAL_IS_HOST_MODULE

###########################################################
## Define PRIVATE_ variables used by multiple module types
###########################################################
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_NO_DEFAULT_COMPILER_FLAGS := \
    $(strip $(LOCAL_NO_DEFAULT_COMPILER_FLAGS))

ifeq ($(strip $(WITH_SYNTAX_CHECK)),)
  LOCAL_NO_SYNTAX_CHECK := true
endif

ifeq ($(strip $(WITH_STATIC_ANALYZER)),)
  LOCAL_NO_STATIC_ANALYZER := true
endif

ifneq ($(strip $(LOCAL_IS_HOST_MODULE)),)
  my_syntax_arch := host
else
  my_syntax_arch := $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
endif

ifeq ($(strip $(my_cc)),)
  ifeq ($(strip $(LOCAL_CLANG)),true)
    my_cc := $(CLANG)
  else
    my_cc := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)CC)
  endif
endif
ifneq ($(LOCAL_NO_STATIC_ANALYZER),true)
  my_cc := $(SYNTAX_TOOLS_PREFIX)/ccc-analyzer $(my_syntax_arch) "$(my_cc)"
else
ifneq ($(LOCAL_NO_SYNTAX_CHECK),true)
  my_cc := $(SYNTAX_TOOLS_PREFIX)/ccc-syntax $(my_syntax_arch) "$(my_cc)"
endif
endif
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CC := $(my_cc)

ifeq ($(strip $(my_cxx)),)
  ifeq ($(strip $(LOCAL_CLANG)),true)
    my_cxx := $(CLANG_CXX)
  else
    my_cxx := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)CXX)
  endif
endif
ifneq ($(LOCAL_NO_STATIC_ANALYZER),true)
  my_cxx := $(SYNTAX_TOOLS_PREFIX)/cxx-analyzer $(my_syntax_arch) "$(my_cxx)"
else
ifneq ($(LOCAL_NO_SYNTAX_CHECK),true)
  my_cxx := $(SYNTAX_TOOLS_PREFIX)/cxx-syntax $(my_syntax_arch) "$(my_cxx)"
endif
endif
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CXX := $(my_cxx)

# TODO: support a mix of standard extensions so that this isn't necessary
LOCAL_CPP_EXTENSION := $(strip $(LOCAL_CPP_EXTENSION))
ifeq ($(LOCAL_CPP_EXTENSION),)
  LOCAL_CPP_EXTENSION := .cpp
endif
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CPP_EXTENSION := $(LOCAL_CPP_EXTENSION)

# Certain modules like libdl have to have symbols resolved at runtime and blow
# up if --no-undefined is passed to the linker.
ifeq ($(strip $(LOCAL_NO_DEFAULT_COMPILER_FLAGS)),)
ifeq ($(strip $(LOCAL_ALLOW_UNDEFINED_SYMBOLS)),)
  my_ldflags +=  $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)NO_UNDEFINED_LDFLAGS)
endif
endif

ifeq (true,$(LOCAL_GROUP_STATIC_LIBRARIES))
$(LOCAL_BUILT_MODULE): PRIVATE_GROUP_STATIC_LIBRARIES := true
else
$(LOCAL_BUILT_MODULE): PRIVATE_GROUP_STATIC_LIBRARIES :=
endif

###########################################################
## Define arm-vs-thumb-mode flags.
###########################################################
LOCAL_ARM_MODE := $(strip $(LOCAL_ARM_MODE))
ifeq ($(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),arm)
arm_objects_mode := $(if $(LOCAL_ARM_MODE),$(LOCAL_ARM_MODE),arm)
normal_objects_mode := $(if $(LOCAL_ARM_MODE),$(LOCAL_ARM_MODE),thumb)

# Read the values from something like TARGET_arm_CFLAGS or
# TARGET_thumb_CFLAGS.  HOST_(arm|thumb)_CFLAGS values aren't
# actually used (although they are usually empty).
arm_objects_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)$(arm_objects_mode)_CFLAGS)
normal_objects_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)$(normal_objects_mode)_CFLAGS)
ifeq ($(strip $(LOCAL_CLANG)),true)
arm_objects_cflags := $(call $(LOCAL_2ND_ARCH_VAR_PREFIX)convert-to-$(my_host)clang-flags,$(arm_objects_cflags))
normal_objects_cflags := $(call $(LOCAL_2ND_ARCH_VAR_PREFIX)convert-to-$(my_host)clang-flags,$(normal_objects_cflags))
endif

else
arm_objects_mode :=
normal_objects_mode :=
arm_objects_cflags :=
normal_objects_cflags :=
endif

###########################################################
## Define per-module debugging flags.  Users can turn on
## debugging for a particular module by setting DEBUG_MODULE_ModuleName
## to a non-empty value in their environment or buildspec.mk,
## and setting HOST_/TARGET_CUSTOM_DEBUG_CFLAGS to the
## debug flags that they want to use.
###########################################################
ifdef DEBUG_MODULE_$(strip $(LOCAL_MODULE))
  debug_cflags := $($(my_prefix)CUSTOM_DEBUG_CFLAGS)
else
  debug_cflags :=
endif

###########################################################
## Stuff source generated from one-off tools
###########################################################
$(my_generated_sources): PRIVATE_MODULE := $(my_register_name)

my_gen_sources_copy := $(patsubst $(generated_sources_dir)/%,$(intermediates)/%,$(filter $(generated_sources_dir)/%,$(my_generated_sources)))

$(my_gen_sources_copy): $(intermediates)/% : $(generated_sources_dir)/% | $(ACP)
	@echo "Copy: $@"
	$(copy-file-to-target)

my_generated_sources := $(patsubst $(generated_sources_dir)/%,$(intermediates)/%,$(my_generated_sources))

ALL_GENERATED_SOURCES += $(my_generated_sources)


###########################################################
## YACC: Compile .y and .yy files to .cpp and the to .o.
###########################################################

y_yacc_sources := $(filter %.y,$(my_src_files))
y_yacc_cpps := $(addprefix \
    $(intermediates)/,$(y_yacc_sources:.y=$(LOCAL_CPP_EXTENSION)))

yy_yacc_sources := $(filter %.yy,$(my_src_files))
yy_yacc_cpps := $(addprefix \
    $(intermediates)/,$(yy_yacc_sources:.yy=$(LOCAL_CPP_EXTENSION)))

yacc_cpps := $(y_yacc_cpps) $(yy_yacc_cpps)
yacc_headers := $(yacc_cpps:$(LOCAL_CPP_EXTENSION)=.h)
yacc_objects := $(yacc_cpps:$(LOCAL_CPP_EXTENSION)=.o)

ifneq ($(strip $(y_yacc_cpps)),)
$(y_yacc_cpps): $(intermediates)/%$(LOCAL_CPP_EXTENSION): \
    $(TOPDIR)$(LOCAL_PATH)/%.y \
    $(lex_cpps) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(call transform-y-to-cpp,$(PRIVATE_CPP_EXTENSION))
$(yacc_headers): $(intermediates)/%.h: $(intermediates)/%$(LOCAL_CPP_EXTENSION)
endif

ifneq ($(strip $(yy_yacc_cpps)),)
$(yy_yacc_cpps): $(intermediates)/%$(LOCAL_CPP_EXTENSION): \
    $(TOPDIR)$(LOCAL_PATH)/%.yy \
    $(lex_cpps) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(call transform-y-to-cpp,$(PRIVATE_CPP_EXTENSION))
$(yacc_headers): $(intermediates)/%.h: $(intermediates)/%$(LOCAL_CPP_EXTENSION)
endif

ifneq ($(strip $(yacc_cpps)),)
$(yacc_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(yacc_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)
$(yacc_objects): $(intermediates)/%.o: $(intermediates)/%$(LOCAL_CPP_EXTENSION)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
endif

###########################################################
## LEX: Compile .l and .ll files to .cpp and then to .o.
###########################################################

l_lex_sources := $(filter %.l,$(my_src_files))
l_lex_cpps := $(addprefix \
    $(intermediates)/,$(l_lex_sources:.l=$(LOCAL_CPP_EXTENSION)))

ll_lex_sources := $(filter %.ll,$(my_src_files))
ll_lex_cpps := $(addprefix \
    $(intermediates)/,$(ll_lex_sources:.ll=$(LOCAL_CPP_EXTENSION)))

lex_cpps := $(l_lex_cpps) $(ll_lex_cpps)
lex_objects := $(lex_cpps:$(LOCAL_CPP_EXTENSION)=.o)

ifneq ($(strip $(l_lex_cpps)),)
$(l_lex_cpps): $(intermediates)/%$(LOCAL_CPP_EXTENSION): \
    $(TOPDIR)$(LOCAL_PATH)/%.l
	$(transform-l-to-cpp)
endif

ifneq ($(strip $(ll_lex_cpps)),)
$(ll_lex_cpps): $(intermediates)/%$(LOCAL_CPP_EXTENSION): \
    $(TOPDIR)$(LOCAL_PATH)/%.ll
	$(transform-l-to-cpp)
endif

ifneq ($(strip $(lex_cpps)),)
$(lex_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(lex_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)
$(lex_objects): $(intermediates)/%.o: \
    $(intermediates)/%$(LOCAL_CPP_EXTENSION) \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    $(yacc_headers)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
endif

###########################################################
## C++: Compile .cpp files to .o.
###########################################################

# we also do this on host modules, even though
# it's not really arm, because there are files that are shared.
cpp_arm_sources    := $(patsubst %$(LOCAL_CPP_EXTENSION).arm,%$(LOCAL_CPP_EXTENSION),$(filter %$(LOCAL_CPP_EXTENSION).arm,$(my_src_files)))
cpp_arm_objects    := $(addprefix $(intermediates)/,$(cpp_arm_sources:$(LOCAL_CPP_EXTENSION)=.o))

cpp_normal_sources := $(filter %$(LOCAL_CPP_EXTENSION),$(my_src_files))
cpp_normal_objects := $(addprefix $(intermediates)/,$(cpp_normal_sources:$(LOCAL_CPP_EXTENSION)=.o))

$(cpp_arm_objects):    PRIVATE_ARM_MODE := $(arm_objects_mode)
$(cpp_arm_objects):    PRIVATE_ARM_CFLAGS := $(arm_objects_cflags)
$(cpp_normal_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(cpp_normal_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)

cpp_objects        := $(cpp_arm_objects) $(cpp_normal_objects)

ifneq ($(strip $(cpp_objects)),)
$(cpp_objects): $(intermediates)/%.o: \
    $(TOPDIR)$(LOCAL_PATH)/%$(LOCAL_CPP_EXTENSION) \
    $(yacc_cpps) $(proto_generated_headers) \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
-include $(cpp_objects:%.o=%.P)
endif

###########################################################
## C++: Compile generated .cpp files to .o.
###########################################################

gen_cpp_sources := $(filter %$(LOCAL_CPP_EXTENSION),$(my_generated_sources))
gen_cpp_objects := $(gen_cpp_sources:%$(LOCAL_CPP_EXTENSION)=%.o)

ifneq ($(strip $(gen_cpp_objects)),)
# Compile all generated files as thumb.
# TODO: support compiling certain generated files as arm.
$(gen_cpp_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(gen_cpp_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)
$(gen_cpp_objects): $(intermediates)/%.o: \
    $(intermediates)/%$(LOCAL_CPP_EXTENSION) $(yacc_cpps) \
    $(proto_generated_headers) \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
-include $(gen_cpp_objects:%.o=%.P)
endif

###########################################################
## S: Compile generated .S and .s files to .o.
###########################################################

gen_S_sources := $(filter %.S,$(my_generated_sources))
gen_S_objects := $(gen_S_sources:%.S=%.o)

ifneq ($(strip $(gen_S_sources)),)
$(gen_S_objects): $(intermediates)/%.o: $(intermediates)/%.S \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)s-to-o)
-include $(gen_S_objects:%.o=%.P)
endif

gen_s_sources := $(filter %.s,$(my_generated_sources))
gen_s_objects := $(gen_s_sources:%.s=%.o)

ifneq ($(strip $(gen_s_objects)),)
$(gen_s_objects): $(intermediates)/%.o: $(intermediates)/%.s \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)s-to-o-no-deps)
-include $(gen_s_objects:%.o=%.P)
endif

gen_asm_objects := $(gen_S_objects) $(gen_s_objects)

###########################################################
## o: Include generated .o files in output.
###########################################################

gen_o_objects := $(filter %.o,$(my_generated_sources))

###########################################################
## C: Compile .c files to .o.
###########################################################

c_arm_sources    := $(patsubst %.c.arm,%.c,$(filter %.c.arm,$(my_src_files)))
c_arm_objects    := $(addprefix $(intermediates)/,$(c_arm_sources:.c=.o))

c_normal_sources := $(filter %.c,$(my_src_files))
c_normal_objects := $(addprefix $(intermediates)/,$(c_normal_sources:.c=.o))

$(c_arm_objects):    PRIVATE_ARM_MODE := $(arm_objects_mode)
$(c_arm_objects):    PRIVATE_ARM_CFLAGS := $(arm_objects_cflags)
$(c_normal_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(c_normal_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)

c_objects        := $(c_arm_objects) $(c_normal_objects)

ifneq ($(strip $(c_objects)),)
$(c_objects): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.c $(yacc_cpps) $(proto_generated_headers) \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)c-to-o)
-include $(c_objects:%.o=%.P)
endif

###########################################################
## C: Compile generated .c files to .o.
###########################################################

gen_c_sources := $(filter %.c,$(my_generated_sources))
gen_c_objects := $(gen_c_sources:%.c=%.o)

ifneq ($(strip $(gen_c_objects)),)
# Compile all generated files as thumb.
# TODO: support compiling certain generated files as arm.
$(gen_c_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(gen_c_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)
$(gen_c_objects): $(intermediates)/%.o: $(intermediates)/%.c $(yacc_cpps) $(proto_generated_headers) \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)c-to-o)
-include $(gen_c_objects:%.o=%.P)
endif

###########################################################
## ObjC: Compile .m files to .o
###########################################################

objc_sources := $(filter %.m,$(my_src_files))
objc_objects := $(addprefix $(intermediates)/,$(objc_sources:.m=.o))

ifneq ($(strip $(objc_objects)),)
$(objc_objects): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.m $(yacc_cpps) $(proto_generated_headers) \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)m-to-o)
-include $(objc_objects:%.o=%.P)
endif

###########################################################
## AS: Compile .S files to .o.
###########################################################

asm_sources_S := $(filter %.S,$(my_src_files))
asm_objects_S := $(addprefix $(intermediates)/,$(asm_sources_S:.S=.o))

ifneq ($(strip $(asm_objects_S)),)
$(asm_objects_S): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.S \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)s-to-o)
-include $(asm_objects_S:%.o=%.P)
endif

asm_sources_s := $(filter %.s,$(my_src_files))
asm_objects_s := $(addprefix $(intermediates)/,$(asm_sources_s:.s=.o))

ifneq ($(strip $(asm_objects_s)),)
$(asm_objects_s): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.s \
    $(LOCAL_ADDITIONAL_DEPENDENCIES) \
    | $(my_compiler_dependencies)
	$(transform-$(PRIVATE_HOST)s-to-o-no-deps)
-include $(asm_objects_s:%.o=%.P)
endif

asm_objects := $(asm_objects_S) $(asm_objects_s)


####################################################
## Import includes
####################################################
import_includes := $(intermediates)/import_includes
import_includes_deps := $(strip \
    $(foreach l, $(installed_shared_library_module_names), \
      $(call intermediates-dir-for,SHARED_LIBRARIES,$(l),$(LOCAL_IS_HOST_MODULE),,$(LOCAL_2ND_ARCH_VAR_PREFIX))/export_includes) \
    $(foreach l, $(my_static_libraries) $(my_whole_static_libraries), \
      $(call intermediates-dir-for,STATIC_LIBRARIES,$(l),$(LOCAL_IS_HOST_MODULE),,$(LOCAL_2ND_ARCH_VAR_PREFIX))/export_includes))
$(import_includes) : $(import_includes_deps)
	@echo Import includes file: $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
ifdef import_includes_deps
	$(hide) for f in $^; do \
	  cat $$f >> $@; \
	done
else
	$(hide) touch $@
endif

###########################################################
## Common object handling.
###########################################################

# some rules depend on asm_objects being first.  If your code depends on
# being first, it's reasonable to require it to be assembly
normal_objects := \
    $(asm_objects) \
    $(cpp_objects) \
    $(gen_cpp_objects) \
    $(gen_asm_objects) \
    $(c_objects) \
    $(gen_c_objects) \
    $(objc_objects) \
    $(yacc_objects) \
    $(lex_objects) \
    $(addprefix $(TOPDIR)$(LOCAL_PATH)/,$(LOCAL_PREBUILT_OBJ_FILES))

all_objects := $(normal_objects) $(gen_o_objects)

my_c_includes += $(TOPDIR)$(LOCAL_PATH) $(intermediates) $(generated_sources_dir)


# all_objects includes gen_o_objects which were part of LOCAL_GENERATED_SOURCES;
# use normal_objects here to avoid creating circular dependencies. This assumes
# that custom build rules which generate .o files don't consume other generated
# sources as input (or if they do they take care of that dependency themselves).
$(normal_objects) : | $(my_generated_sources)
$(all_objects) : | $(import_includes)
ALL_C_CPP_ETC_OBJECTS += $(all_objects)


###########################################################
# Standard library handling.
###########################################################

###########################################################
# The list of libraries that this module will link against are in
# these variables.  Each is a list of bare module names like "libc libm".
#
# LOCAL_SHARED_LIBRARIES
# LOCAL_STATIC_LIBRARIES
# LOCAL_WHOLE_STATIC_LIBRARIES
#
# We need to convert the bare names into the dependencies that
# we'll use for LOCAL_BUILT_MODULE and LOCAL_INSTALLED_MODULE.
# LOCAL_BUILT_MODULE should depend on the BUILT versions of the
# libraries, so that simply building this module doesn't force
# an install of a library.  Similarly, LOCAL_INSTALLED_MODULE
# should depend on the INSTALLED versions of the libraries so
# that they get installed when this module does.
###########################################################
# NOTE:
# WHOLE_STATIC_LIBRARIES are libraries that are pulled into the
# module without leaving anything out, which is useful for turning
# a collection of .a files into a .so file.  Linking against a
# normal STATIC_LIBRARY will only pull in code/symbols that are
# referenced by the module. (see gcc/ld's --whole-archive option)
###########################################################

# Get the list of BUILT libraries, which are under
# various intermediates directories.
so_suffix := $($(my_prefix)SHLIB_SUFFIX)
a_suffix := $($(my_prefix)STATIC_LIB_SUFFIX)

built_shared_libraries := \
    $(addprefix $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_INTERMEDIATE_LIBRARIES)/, \
      $(addsuffix $(so_suffix), \
        $(installed_shared_library_module_names)))

built_static_libraries := \
    $(foreach lib,$(my_static_libraries), \
      $(call intermediates-dir-for, \
        STATIC_LIBRARIES,$(lib),$(LOCAL_IS_HOST_MODULE),,$(LOCAL_2ND_ARCH_VAR_PREFIX))/$(lib)$(a_suffix))

built_whole_libraries := \
    $(foreach lib,$(my_whole_static_libraries), \
      $(call intermediates-dir-for, \
        STATIC_LIBRARIES,$(lib),$(LOCAL_IS_HOST_MODULE),,$(LOCAL_2ND_ARCH_VAR_PREFIX))/$(lib)$(a_suffix))

# Default is -fno-rtti.
ifeq ($(strip $(LOCAL_RTTI_FLAG)),)
LOCAL_RTTI_FLAG := -fno-rtti
endif

###########################################################
# Rule-specific variable definitions
###########################################################

ifeq ($(LOCAL_CLANG),true)
my_cflags := $(call $(LOCAL_2ND_ARCH_VAR_PREFIX)convert-to-$(my_host)clang-flags,$(my_cflags))
my_cppflags := $(call $(LOCAL_2ND_ARCH_VAR_PREFIX)convert-to-$(my_host)clang-flags,$(my_cppflags))
my_asflags := $(call $(LOCAL_2ND_ARCH_VAR_PREFIX)convert-to-$(my_host)clang-flags,$(my_asflags))
my_ldflags := $(call $(LOCAL_2ND_ARCH_VAR_PREFIX)convert-to-$(my_host)clang-flags,$(my_ldflags))
endif

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_YACCFLAGS := $(LOCAL_YACCFLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ASFLAGS := $(my_asflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CONLYFLAGS := $(LOCAL_CONLYFLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CFLAGS := $(my_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CPPFLAGS := $(my_cppflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_RTTI_FLAG := $(LOCAL_RTTI_FLAG)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_DEBUG_CFLAGS := $(debug_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_C_INCLUDES := $(my_c_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_IMPORT_INCLUDES := $(import_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_LDFLAGS := $(my_ldflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_LDLIBS := $(LOCAL_LDLIBS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_NO_CRT := $(strip $(LOCAL_NO_CRT) $(LOCAL_NO_CRT_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)))

# this is really the way to get the files onto the command line instead
# of using $^, because then LOCAL_ADDITIONAL_DEPENDENCIES doesn't work
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_SHARED_LIBRARIES := $(built_shared_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_STATIC_LIBRARIES := $(built_static_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(built_whole_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_OBJECTS := $(all_objects)

###########################################################
# Define library dependencies.
###########################################################
# all_libraries is used for the dependencies on LOCAL_BUILT_MODULE.
all_libraries := \
    $(built_shared_libraries) \
    $(built_static_libraries) \
    $(built_whole_libraries)

###########################################################
# Export includes
###########################################################
export_includes := $(intermediates)/export_includes
$(export_includes): PRIVATE_EXPORT_C_INCLUDE_DIRS := $(LOCAL_EXPORT_C_INCLUDE_DIRS)
$(export_includes) : $(LOCAL_MODULE_MAKEFILE)
	@echo Export includes file: $< -- $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
ifdef LOCAL_EXPORT_C_INCLUDE_DIRS
	$(hide) for d in $(PRIVATE_EXPORT_C_INCLUDE_DIRS); do \
	        echo "-I $$d" >> $@; \
	        done
else
	$(hide) touch $@
endif

# Make sure export_includes gets generated when you are running mm/mmm
$(LOCAL_BUILT_MODULE) : | $(export_includes)
