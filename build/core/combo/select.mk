# Select a combo based on the compiler being used.
#
# Inputs:
#	combo_target -- prefix for final variables (HOST_ or TARGET_)
#	combo_2nd_arch_prefix -- it's defined if this is loaded for TARGET_2ND_ARCH.
#

# Build a target string like "linux-arm" or "darwin-x86".
ifdef combo_2nd_arch_prefix
combo_os_arch := $($(combo_target)OS)-$(TARGET_2ND_ARCH)
else
combo_os_arch := $($(combo_target)OS)-$($(combo_target)ARCH)
endif

combo_var_prefix := $(combo_2nd_arch_prefix)$(combo_target)

# Set reasonable defaults for the various variables

$(combo_var_prefix)CC := $(CC)
$(combo_var_prefix)CXX := $(CXX)
$(combo_var_prefix)AR := $(AR)
$(combo_var_prefix)STRIP := $(STRIP)

$(combo_var_prefix)BINDER_MINI := 0

$(combo_var_prefix)HAVE_EXCEPTIONS := 0
$(combo_var_prefix)HAVE_UNIX_FILE_PATH := 1
$(combo_var_prefix)HAVE_WINDOWS_FILE_PATH := 0
$(combo_var_prefix)HAVE_RTTI := 1
$(combo_var_prefix)HAVE_CALL_STACKS := 1
$(combo_var_prefix)HAVE_64BIT_IO := 1
$(combo_var_prefix)HAVE_CLOCK_TIMERS := 1
$(combo_var_prefix)HAVE_PTHREAD_RWLOCK := 1
$(combo_var_prefix)HAVE_STRNLEN := 1
$(combo_var_prefix)HAVE_STRERROR_R_STRRET := 1
$(combo_var_prefix)HAVE_STRLCPY := 0
$(combo_var_prefix)HAVE_STRLCAT := 0
$(combo_var_prefix)HAVE_KERNEL_MODULES := 0

$(combo_var_prefix)GLOBAL_CFLAGS := -fno-exceptions -Wno-multichar
$(combo_var_prefix)RELEASE_CFLAGS := -O2 -g -fno-strict-aliasing
$(combo_var_prefix)GLOBAL_CPPFLAGS :=
$(combo_var_prefix)GLOBAL_LDFLAGS :=
$(combo_var_prefix)GLOBAL_ARFLAGS := crsPD
$(combo_var_prefix)GLOBAL_LD_DIRS :=

$(combo_var_prefix)EXECUTABLE_SUFFIX :=
$(combo_var_prefix)SHLIB_SUFFIX := .so
$(combo_var_prefix)STATIC_LIB_SUFFIX := .a

# Now include the combo for this specific target.
include $(BUILD_COMBOS)/$(combo_target)$(combo_os_arch).mk
