#
# Handle various build version information.
#
# Guarantees that the following are defined:
#     PLATFORM_VERSION
#     PLATFORM_VERSION_CODENAME
#     BUILD_ID
#     BUILD_NUMBER
#

# Look for an optional file containing overrides of the defaults,
# but don't cry if we don't find it.  We could just use -include, but
# the build.prop target also wants INTERNAL_BUILD_ID_MAKEFILE to be set
# if the file exists.
#
INTERNAL_BUILD_ID_MAKEFILE := $(wildcard $(BUILD_SYSTEM)/build_id.mk)
ifneq "" "$(INTERNAL_BUILD_ID_MAKEFILE)"
  include $(INTERNAL_BUILD_ID_MAKEFILE)
endif

ifeq "" "$(PLATFORM_VERSION)"
  # This is the canonical definition of the platform version,
  # which is the version that we reveal to the end user.
  # Update this value when the platform version changes (rather
  # than overriding it somewhere else).  Can be an arbitrary string.
  PLATFORM_VERSION := 1.0.00
endif

ifeq "" "$(PLATFORM_VERSION_CODENAME)"
  # This is the current development code-name, if the build is not a final
  # release build.  If this is a final release build, it is simply "REL".
  PLATFORM_VERSION_CODENAME := REL
endif

ifeq "" "$(BUILD_ID)"
  # Used to signify special builds.  E.g., branches and/or releases,
  # like "M5-RC7".  Can be an arbitrary string, but must be a single
  # word and a valid file name.
  #
  # If there is no BUILD_ID set, make it obvious.
  BUILD_ID := UNKNOWN
endif

ifeq "" "$(BUILD_NUMBER)"
  # BUILD_NUMBER should be set to the source control value that
  # represents the current state of the source code.  E.g., a
  # perforce changelist number or a git hash.  Can be an arbitrary string
  # (to allow for source control that uses something other than numbers),
  # but must be a single word and a valid file name.
  #
  # If no BUILD_NUMBER is set, create a useful "I am an engineering build
  # from this date/time" value.  Make it start with a non-digit so that
  # anyone trying to parse it as an integer will probably get "0".
  BUILD_NUMBER := eng.$(USER).$(shell date +%Y%m%d.%H%M%S)
endif
