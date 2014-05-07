##
## Common build system definitions.  Mostly standard
## commands for building various types of targets, which
## are used by others to construct the final targets.
##

# These are variables we use to collect overall lists
# of things being processed.

# Full paths to all of the documentation
ALL_DOCS:=

# The short names of all of the targets in the system.
# For each element of ALL_MODULES, two other variables
# are defined:
#   $(ALL_MODULES.$(target)).BUILT
#   $(ALL_MODULES.$(target)).INSTALLED
# The BUILT variable contains LOCAL_BUILT_MODULE for that
# target, and the INSTALLED variable contains the LOCAL_INSTALLED_MODULE.
# Some targets may have multiple files listed in the BUILT and INSTALLED
# sub-variables.
ALL_MODULES:=

# Full paths to targets that should be added to the "make droid"
# set of installed targets.
ALL_DEFAULT_INSTALLED_MODULES:=

# The list of tags that have been defined by
# LOCAL_MODULE_TAGS.  Each word in this variable maps
# to a corresponding ALL_MODULE_TAGS.<tagname> variable
# that contains all of the INSTALLED_MODULEs with that tag.
ALL_MODULE_TAGS:=

# Similar to ALL_MODULE_TAGS, but contains the short names
# of all targets for a particular tag.  The top-level variable
# won't have the list of tags;  ust ALL_MODULE_TAGS to get
# the list of all known tags.  (This means that this variable
# will always be empty; it's just here as a placeholder for
# its sub-variables.)
ALL_MODULE_NAME_TAGS:=

# Full paths to all prebuilt files that will be copied
# (used to make the dependency on acp)
ALL_PREBUILT:=

# Full path to all files that are made by some tool
ALL_GENERATED_SOURCES:=

# Full path to all asm, C, C++, lex and yacc generated C files.
# These all have an order-only dependency on the copied headers
ALL_C_CPP_ETC_OBJECTS:=

# The list of dynamic binaries that haven't been stripped/compressed/etc.
ALL_ORIGINAL_DYNAMIC_BINARIES:=

# All findbugs xml files
ALL_FINDBUGS_FILES:=

# GPL module license files
ALL_GPL_MODULE_LICENSE_FILES:=

# Target and host installed module's dependencies on shared libraries.
# They are list of "<module_name>:<installed_file>:lib1,lib2...".
TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES :=
2ND_TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES :=
HOST_DEPENDENCIES_ON_SHARED_LIBRARIES :=

###########################################################
## Debugging; prints a variable list to stdout
###########################################################

# $(1): variable name list, not variable values
define print-vars
$(foreach var,$(1), \
  $(info $(var):) \
  $(foreach word,$($(var)), \
    $(info $(space)$(space)$(word)) \
   ) \
 )
endef

###########################################################
## Evaluates to true if the string contains the word true,
## and empty otherwise
## $(1): a var to test
###########################################################

define true-or-empty
$(filter true, $(1))
endef


###########################################################
## Retrieve the directory of the current makefile
## Must be called before including any other makefile!!
###########################################################

# Figure out where we are.
define my-dir
$(strip \
  $(eval LOCAL_MODULE_MAKEFILE := $$(lastword $$(MAKEFILE_LIST))) \
  $(if $(filter $(BUILD_SYSTEM)/% $(OUT_DIR)/%,$(LOCAL_MODULE_MAKEFILE)), \
    $(error my-dir must be called before including any other makefile.) \
   , \
    $(patsubst %/,%,$(dir $(LOCAL_MODULE_MAKEFILE))) \
   ) \
 )
endef

###########################################################
## Retrieve a list of all makefiles immediately below some directory
###########################################################

define all-makefiles-under
$(wildcard $(1)/*/$(VMW_MAKEFILE_NAME))
endef

###########################################################
## Look under a directory for makefiles that don't have parent
## makefiles.
###########################################################

# $(1): directory to search under
# Ignores $(1)/$(VMW_MAKEFILE_NAME)
define first-makefiles-under
$(shell build/tools/findleaves.py --prune=$(OUT_DIR) --prune=.repo --prune=.git \
        --mindepth=2 $(1) $(VMW_MAKEFILE_NAME))
endef

###########################################################
## Retrieve a list of all makefiles immediately below your directory
## Must be called before including any other makefile!!
###########################################################

define all-subdir-makefiles
$(call all-makefiles-under,$(call my-dir))
endef

###########################################################
## Look in the named list of directories for makefiles,
## relative to the current directory.
## Must be called before including any other makefile!!
###########################################################

# $(1): List of directories to look for under this directory
define all-named-subdir-makefiles
$(wildcard $(addsuffix /$(VMW_MAKEFILE_NAME), $(addprefix $(call my-dir)/,$(1))))
endef

###########################################################
## Find all of the c files under the named directories.
## Meant to be used like:
##    SRC_FILES := $(call all-c-files-under,src tests)
###########################################################

define all-c-files-under
$(patsubst ./%,%, \
  $(shell cd $(LOCAL_PATH) ; \
          find -L $(1) -name "*.c" -and -not -name ".*") \
 )
endef

###########################################################
## Find all of the c files from here.  Meant to be used like:
##    SRC_FILES := $(call all-subdir-c-files)
###########################################################

define all-subdir-c-files
$(call all-c-files-under,.)
endef

###########################################################
## Find all of the S files under the named directories.
## Meant to be used like:
##    SRC_FILES := $(call all-c-files-under,src tests)
###########################################################

define all-S-files-under
$(patsubst ./%,%, \
  $(shell cd $(LOCAL_PATH) ; \
          find -L $(1) -name "*.S" -and -not -name ".*") \
 )
endef

###########################################################
## Find all of the files matching pattern
##    SRC_FILES := $(call find-subdir-files, <pattern>)
###########################################################

define find-subdir-files
$(patsubst ./%,%,$(shell cd $(LOCAL_PATH) ; find -L $(1)))
endef

###########################################################
# find the files in the subdirectory $1 of LOCAL_DIR
# matching pattern $2, filtering out files $3
# e.g.
#     SRC_FILES += $(call find-subdir-subdir-files, \
#                         css, *.cpp, DontWantThis.cpp)
###########################################################

define find-subdir-subdir-files
$(filter-out $(patsubst %,$(1)/%,$(3)),$(patsubst ./%,%,$(shell cd \
            $(LOCAL_PATH) ; find -L $(1) -maxdepth 1 -name $(2))))
endef

###########################################################
## Find all of the files matching pattern
## 
###########################################################

define find-subdir-assets
$(if $(1),$(patsubst ./%,%, \
	$(shell if [ -d $(1) ] ; then cd $(1) ; find ./ -not -name '.*' -and -type f -and -not -type l ; fi)), \
	$(warning Empty argument supplied to find-subdir-assets) \
)
endef

###########################################################
# Use utility find to find given files in the given subdirs.
# This function uses $(1), instead of LOCAL_PATH as the base.
# $(1): the base dir, relative to the root of the source tree.
# $(2): the file name pattern to be passed to find as "-name".
# $(3): a list of subdirs of the base dir.
# Returns: a list of paths relative to the base dir.
###########################################################

define find-files-in-subdirs
$(patsubst ./%,%, \
  $(shell cd $(1) ; \
          find -L $(3) -name $(2) -and -not -name ".*") \
 )
endef

###########################################################
## Scan through each directory of $(1) looking for files
## that match $(2) using $(wildcard).  Useful for seeing if
## a given directory or one of its parents contains
## a particular file.  Returns the first match found,
## starting furthest from the root.
###########################################################

define find-parent-file
$(strip \
  $(eval _fpf := $(wildcard $(foreach f, $(2), $(strip $(1))/$(f)))) \
  $(if $(_fpf),$(_fpf), \
       $(if $(filter-out ./ .,$(1)), \
             $(call find-parent-file,$(patsubst %/,%,$(dir $(1))),$(2)) \
        ) \
   ) \
)
endef

###########################################################
## Function we can evaluate to introduce a dynamic dependency
###########################################################

define add-dependency
$(1): $(2)
endef

###########################################################
## The intermediates directory.  Where object files go for
## a given target.  We could technically get away without
## the "_intermediates" suffix on the directory, but it's
## nice to be able to grep for that string to find out if
## anyone's abusing the system.
###########################################################

# $(1): target class, like "APPS"
# $(2): target name, like "NotePad"
# $(3): if non-empty, this is a HOST target.
# $(4): if non-empty, force the intermediates to be COMMON
# $(5): if non-empty, force the intermedistes to be for the 2nd arch
define intermediates-dir-for
$(strip \
    $(eval _idfClass := $(strip $(1))) \
    $(if $(_idfClass),, \
        $(error $(LOCAL_PATH): Class not defined in call to intermediates-dir-for)) \
    $(eval _idfName := $(strip $(2))) \
    $(if $(_idfName),, \
        $(error $(LOCAL_PATH): Name not defined in call to intermediates-dir-for)) \
    $(eval _idfPrefix := $(if $(strip $(3)),HOST,TARGET)) \
    $(eval _idf2ndArchPrefix := $(if $(call directory_is_64_bit_blacklisted,$(LOCAL_PATH))$(strip $(5)),$(TARGET_2ND_ARCH_VAR_PREFIX))) \
    $(if $(filter $(_idfPrefix)-$(_idfClass),$(COMMON_MODULE_CLASSES))$(4), \
        $(eval _idfIntBase := $($(_idfPrefix)_OUT_COMMON_INTERMEDIATES)) \
      ,$(if $(filter $(_idfPrefix)-$(_idfClass),TARGET-SHARED_LIBRARIES TARGET-STATIC_LIBRARIES TARGET-EXECUTABLES),\
          $(eval _idfIntBase := $($(_idf2ndArchPrefix)$(_idfPrefix)_OUT_INTERMEDIATES)) \
       ,$(eval _idfIntBase := $($(_idfPrefix)_OUT_INTERMEDIATES)) \
       ) \
     ) \
    $(_idfIntBase)/$(_idfClass)/$(_idfName)_intermediates \
)
endef

# Uses LOCAL_MODULE_CLASS, LOCAL_MODULE, and LOCAL_IS_HOST_MODULE
# to determine the intermediates directory.
#
# $(1): if non-empty, force the intermediates to be COMMON
# $(2): if non-empty, force the intermediates to be for the 2nd arch
define local-intermediates-dir
$(strip \
    $(if $(strip $(LOCAL_MODULE_CLASS)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS not defined before call to local-intermediates-dir)) \
    $(if $(strip $(LOCAL_MODULE)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE not defined before call to local-intermediates-dir)) \
    $(call intermediates-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE),$(LOCAL_IS_HOST_MODULE),$(1),$(2)) \
)
endef

###########################################################
## The generated sources directory.  Placing generated
## source files directly in the intermediates directory
## causes problems for multiarch builds, where there are
## two intermediates directories for a single target. Put
## them in a separate directory, and they will be copied to
## each intermediates directory automatically.
###########################################################

# $(1): target class, like "APPS"
# $(2): target name, like "NotePad"
# $(3): if non-empty, this is a HOST target.
# $(4): if non-empty, force the generated sources to be COMMON
define generated-sources-dir-for
$(strip \
    $(eval _idfClass := $(strip $(1))) \
    $(if $(_idfClass),, \
        $(error $(LOCAL_PATH): Class not defined in call to generated-sources-dir-for)) \
    $(eval _idfName := $(strip $(2))) \
    $(if $(_idfName),, \
        $(error $(LOCAL_PATH): Name not defined in call to generated-sources-dir-for)) \
    $(eval _idfPrefix := $(if $(strip $(3)),HOST,TARGET)) \
    $(if $(filter $(_idfPrefix)-$(_idfClass),$(COMMON_MODULE_CLASSES))$(4), \
        $(eval _idfIntBase := $($(_idfPrefix)_OUT_GEN_COMMON)) \
      , \
        $(eval _idfIntBase := $($(_idfPrefix)_OUT_GEN)) \
     ) \
    $(_idfIntBase)/$(_idfClass)/$(_idfName)_intermediates \
)
endef

# Uses LOCAL_MODULE_CLASS, LOCAL_MODULE, and LOCAL_IS_HOST_MODULE
# to determine the generated sources directory.
#
# $(1): if non-empty, force the intermediates to be COMMON
define local-generated-sources-dir
$(strip \
    $(if $(strip $(LOCAL_MODULE_CLASS)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS not defined before call to local-generated-sources-dir)) \
    $(if $(strip $(LOCAL_MODULE)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE not defined before call to local-generated-sources-dir)) \
    $(call generated-sources-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE),$(LOCAL_IS_HOST_MODULE),$(1)) \
)
endef

###########################################################
## Convert "path/to/libXXX.so" to "-lXXX".
## Any "path/to/libXXX.a" elements pass through unchanged.
###########################################################

define normalize-libraries
$(foreach so,$(filter %.so,$(1)),-l$(patsubst lib%.so,%,$(notdir $(so))))\
$(filter-out %.so,$(1))
endef

# TODO: change users to call the common version.
define normalize-host-libraries
$(call normalize-libraries,$(1))
endef

define normalize-target-libraries
$(call normalize-libraries,$(1))
endef

###########################################################
## Convert a list of short module names (e.g., "framework", "Browser")
## into the list of files that are built for those modules.
## NOTE: this won't return reliable results until after all
## sub-makefiles have been included.
## $(1): target list
###########################################################

define module-built-files
$(foreach module,$(1),$(ALL_MODULES.$(module).BUILT))
endef

###########################################################
## Convert a list of short modules names (e.g., "framework", "Browser")
## into the list of files that are installed for those modules.
## NOTE: this won't return reliable results until after all
## sub-makefiles have been included.
## $(1): target list
###########################################################

define module-installed-files
$(foreach module,$(1),$(ALL_MODULES.$(module).INSTALLED))
endef

###########################################################
## Convert a list of short modules names (e.g., "framework", "Browser")
## into the list of files that should be used when linking
## against that module as a public API.
## NOTE: this won't return reliable results until after all
## sub-makefiles have been included.
## $(1): target list
###########################################################

define module-stubs-files
$(foreach module,$(1),$(ALL_MODULES.$(module).STUBS))
endef

###########################################################
## Evaluates to the timestamp file for a doc module, which
## is the dependency that should be used.
## $(1): doc module
###########################################################

define doc-timestamp-for
$(OUT_DOCS)/$(strip $(1))-timestamp
endef


###########################################################
## Run rot13 on a string
## $(1): the string.  Must be one line.
###########################################################
define rot13
$(shell echo $(1) | tr 'a-zA-Z' 'n-za-mN-ZA-M')
endef


###########################################################
## Returns true if $(1) and $(2) are equal.  Returns
## the empty string if they are not equal.
###########################################################
define streq
$(strip $(if $(strip $(1)),\
  $(if $(strip $(2)),\
    $(if $(filter-out __,_$(subst $(strip $(1)),,$(strip $(2)))$(subst $(strip $(2)),,$(strip $(1)))_),,true), \
    ),\
  $(if $(strip $(2)),\
    ,\
    true)\
 ))
endef

###########################################################
## Convert "a b c" into "a:b:c"
###########################################################
define normalize-path-list
$(subst $(space),:,$(strip $(1)))
endef

###########################################################
## Read the word out of a colon-separated list of words.
## This has the same behavior as the built-in function
## $(word n,str).
##
## The individual words may not contain spaces.
##
## $(1): 1 based index
## $(2): value of the form a:b:c...
###########################################################

define word-colon
$(word $(1),$(subst :,$(space),$(2)))
endef

###########################################################
## Convert "a=b c= d e = f" into "a=b c=d e=f"
##
## $(1): list to collapse
## $(2): if set, separator word; usually "=", ":", or ":="
##       Defaults to "=" if not set.
###########################################################

define collapse-pairs
$(eval _cpSEP := $(strip $(if $(2),$(2),=)))\
$(subst $(space)$(_cpSEP)$(space),$(_cpSEP),$(strip \
    $(subst $(_cpSEP), $(_cpSEP) ,$(1))))
endef

###########################################################
## Given a list of pairs, if multiple pairs have the same
## first components, keep only the first pair.
##
## $(1): list of pairs
## $(2): the separator word, such as ":", "=", etc.
define uniq-pairs-by-first-component
$(eval _upbfc_fc_set :=)\
$(strip $(foreach w,$(1), $(eval _first := $(word 1,$(subst $(2),$(space),$(w))))\
    $(if $(filter $(_upbfc_fc_set),$(_first)),,$(w)\
        $(eval _upbfc_fc_set += $(_first)))))\
$(eval _upbfc_fc_set :=)\
$(eval _first:=)
endef

###########################################################
## MODULE_TAG set operations
###########################################################

# Given a list of tags, return the targets that specify
# any of those tags.
# $(1): tag list
define modules-for-tag-list
$(sort $(foreach tag,$(1),$(ALL_MODULE_TAGS.$(tag))))
endef

# Same as modules-for-tag-list, but operates on
# ALL_MODULE_NAME_TAGS.
# $(1): tag list
define module-names-for-tag-list
$(sort $(foreach tag,$(1),$(ALL_MODULE_NAME_TAGS.$(tag))))
endef

# Given an accept and reject list, find the matching
# set of targets.  If a target has multiple tags and
# any of them are rejected, the target is rejected.
# Reject overrides accept.
# $(1): list of tags to accept
# $(2): list of tags to reject
#TODO(dbort): do $(if $(strip $(1)),$(1),$(ALL_MODULE_TAGS))
#TODO(jbq): as of 20100106 nobody uses the second parameter
define get-tagged-modules
$(filter-out \
	$(call modules-for-tag-list,$(2)), \
	    $(call modules-for-tag-list,$(1)))
endef

###########################################################
## Append a leaf to a base path.  Properly deals with
## base paths ending in /.
##
## $(1): base path
## $(2): leaf path
###########################################################

define append-path
$(subst //,/,$(1)/$(2))
endef


###########################################################
## Package filtering
###########################################################

# Given a list of installed modules (short or long names)
# return a list of the packages (yes, .apk packages, not
# modules in general) that are overridden by this list and,
# therefore, should not be installed.
# $(1): mixed list of installed modules
# TODO: This is fragile; find a reliable way to get this information.
define _get-package-overrides
 $(eval ### Discard any words containing slashes, unless they end in .apk, \
        ### in which case trim off the directory component and the suffix. \
        ### If there are no slashes, keep the entire word.)
 $(eval _gpo_names := $(subst /,@@@ @@@,$(1)))
 $(eval _gpo_names := \
     $(filter %.apk,$(_gpo_names)) \
     $(filter-out %@@@ @@@%,$(_gpo_names)))
 $(eval _gpo_names := $(patsubst %.apk,%,$(_gpo_names)))
 $(eval _gpo_names := $(patsubst @@@%,%,$(_gpo_names)))

 $(eval ### Remove any remaining words that contain dots.)
 $(eval _gpo_names := $(subst .,@@@ @@@,$(_gpo_names)))
 $(eval _gpo_names := $(filter-out %@@@ @@@%,$(_gpo_names)))

 $(eval ### Now we have a list of any words that could possibly refer to \
        ### packages, although there may be words that do not.  Only \
        ### real packages will be present under PACKAGES.*, though.)
 $(foreach _gpo_name,$(_gpo_names),$(PACKAGES.$(_gpo_name).OVERRIDES))
endef

define get-package-overrides
$(sort $(strip $(call _get-package-overrides,$(1))))
endef

###########################################################
## Output the command lines, or not
###########################################################

ifeq ($(strip $(SHOW_COMMANDS)),)
define pretty
@echo $1
endef
hide := @
else
define pretty
endef
hide :=
endif

###########################################################
## Dump the variables that are associated with targets
###########################################################

define dump-module-variables
@echo all_dependencies=$^
@echo PRIVATE_YACCFLAGS=$(PRIVATE_YACCFLAGS);
@echo PRIVATE_CFLAGS=$(PRIVATE_CFLAGS);
@echo PRIVATE_CPPFLAGS=$(PRIVATE_CPPFLAGS);
@echo PRIVATE_DEBUG_CFLAGS=$(PRIVATE_DEBUG_CFLAGS);
@echo PRIVATE_C_INCLUDES=$(PRIVATE_C_INCLUDES);
@echo PRIVATE_LDFLAGS=$(PRIVATE_LDFLAGS);
@echo PRIVATE_LDLIBS=$(PRIVATE_LDLIBS);
@echo PRIVATE_ARFLAGS=$(PRIVATE_ARFLAGS);
@echo PRIVATE_ALL_SHARED_LIBRARIES=$(PRIVATE_ALL_SHARED_LIBRARIES);
@echo PRIVATE_ALL_STATIC_LIBRARIES=$(PRIVATE_ALL_STATIC_LIBRARIES);
@echo PRIVATE_ALL_WHOLE_STATIC_LIBRARIES=$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES);
@echo PRIVATE_ALL_OBJECTS=$(PRIVATE_ALL_OBJECTS);
@echo PRIVATE_NO_CRT=$(PRIVATE_NO_CRT);
endef

###########################################################
## Commands for using sed to replace given variable values
###########################################################

define transform-variables
@mkdir -p $(dir $@)
@echo "Sed: $(if $(PRIVATE_MODULE),$(PRIVATE_MODULE),$@) <= $<"
$(hide) sed $(foreach var,$(REPLACE_VARS),-e "s/{{$(var)}}/$(subst /,\/,$(PWD)/$($(var)))/g") $< >$@
$(hide) if [ "$(suffix $@)" = ".sh" ]; then chmod a+rx $@; fi
endef


###########################################################
## Commands for munging the dependency files GCC generates
###########################################################
# $(1): the input .d file
# $(2): the output .P file
define transform-d-to-p-args
$(hide) cp $(1) $(2); \
	sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
		-e '/^$$/ d' -e 's/$$/ :/' < $(1) >> $(2); \
	rm -f $(1)
endef

define transform-d-to-p
$(call transform-d-to-p-args,$(@:%.o=%.d),$(@:%.o=%.P))
endef

###########################################################
## Commands for running lex
###########################################################

define transform-l-to-cpp
@mkdir -p $(dir $@)
@echo "Lex: $(PRIVATE_MODULE) <= $<"
$(hide) $(LEX) -o$@ $<
endef

###########################################################
## Commands for running yacc
##
## Because the extension of c++ files can change, the
## extension must be specified in $1.
## E.g, "$(call transform-y-to-cpp,.cpp)"
###########################################################

define transform-y-to-cpp
@mkdir -p $(dir $@)
@echo "Yacc: $(PRIVATE_MODULE) <= $<"
$(YACC) $(PRIVATE_YACCFLAGS) -o $@ $<
touch $(@:$1=$(YACC_HEADER_SUFFIX))
echo '#ifndef '$(@F:$1=_h) > $(@:$1=.h)
echo '#define '$(@F:$1=_h) >> $(@:$1=.h)
cat $(@:$1=$(YACC_HEADER_SUFFIX)) >> $(@:$1=.h)
echo '#endif' >> $(@:$1=.h)
endef


###########################################################
## Commands for running gcc to compile a C++ file
###########################################################

define transform-cpp-to-o
@mkdir -p $(dir $@)
@echo "target $(PRIVATE_ARM_MODE) C++: $(PRIVATE_MODULE) <= $<"
$(hide) $(PRIVATE_CXX) \
	$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	$(shell cat $(PRIVATE_IMPORT_INCLUDES)) \
	$(addprefix -isystem ,\
	    $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	        $(filter-out $(PRIVATE_C_INCLUDES), \
	            $(PRIVATE_TARGET_PROJECT_INCLUDES) \
	            $(PRIVATE_TARGET_C_INCLUDES)))) \
	-c \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	    $(PRIVATE_TARGET_GLOBAL_CFLAGS) \
	    $(PRIVATE_TARGET_GLOBAL_CPPFLAGS) \
	    $(PRIVATE_ARM_CFLAGS) \
	 ) \
	$(PRIVATE_RTTI_FLAG) \
	$(PRIVATE_CFLAGS) \
	$(PRIVATE_CPPFLAGS) \
	$(PRIVATE_DEBUG_CFLAGS) \
	-MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
$(transform-d-to-p)
endef


###########################################################
## Commands for running gcc to compile a C file
###########################################################

# $(1): extra flags
define transform-c-or-s-to-o-no-deps
@mkdir -p $(dir $@)
$(hide) $(PRIVATE_CC) \
	$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	$(shell cat $(PRIVATE_IMPORT_INCLUDES)) \
	$(addprefix -isystem ,\
	    $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	        $(filter-out $(PRIVATE_C_INCLUDES), \
	            $(PRIVATE_TARGET_PROJECT_INCLUDES) \
	            $(PRIVATE_TARGET_C_INCLUDES)))) \
	-c \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	    $(PRIVATE_TARGET_GLOBAL_CFLAGS) \
	    $(PRIVATE_ARM_CFLAGS) \
	 ) \
	 $(1) \
	-MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef

define transform-c-to-o-no-deps
@echo "target $(PRIVATE_ARM_MODE) C: $(PRIVATE_MODULE) <= $<"
$(call transform-c-or-s-to-o-no-deps, $(PRIVATE_CFLAGS) $(PRIVATE_CONLYFLAGS) $(PRIVATE_DEBUG_CFLAGS))
endef

define transform-s-to-o-no-deps
@echo "target asm: $(PRIVATE_MODULE) <= $<"
$(call transform-c-or-s-to-o-no-deps, $(PRIVATE_ASFLAGS))
endef

define transform-c-to-o
$(transform-c-to-o-no-deps)
$(transform-d-to-p)
endef

define transform-s-to-o
$(transform-s-to-o-no-deps)
$(transform-d-to-p)
endef


###########################################################
## Commands for running gcc to compile a host C++ file
###########################################################

define transform-host-cpp-to-o
@mkdir -p $(dir $@)
@echo "host C++: $(PRIVATE_MODULE) <= $<"
$(hide) $(PRIVATE_CXX) \
	$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	$(shell cat $(PRIVATE_IMPORT_INCLUDES)) \
	$(addprefix -isystem ,\
	    $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	        $(filter-out $(PRIVATE_C_INCLUDES), \
	            $(HOST_PROJECT_INCLUDES) \
	            $(PRIVATE_HOST_C_INCLUDES)))) \
	-c \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	    $(PRIVATE_HOST_GLOBAL_CFLAGS) \
	    $(PRIVATE_HOST_GLOBAL_CPPFLAGS) \
	 ) \
	$(PRIVATE_CFLAGS) \
	$(PRIVATE_CPPFLAGS) \
	$(PRIVATE_DEBUG_CFLAGS) \
	-MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
$(transform-d-to-p)
endef


###########################################################
## Commands for running gcc to compile a host C file
###########################################################

# $(1): extra flags
define transform-host-c-or-s-to-o-no-deps
@mkdir -p $(dir $@)
$(hide) $(PRIVATE_CC) \
	$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	$(shell cat $(PRIVATE_IMPORT_INCLUDES)) \
	$(addprefix -isystem ,\
	    $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	        $(filter-out $(PRIVATE_C_INCLUDES), \
	            $(HOST_PROJECT_INCLUDES) \
	            $(PRIVATE_HOST_C_INCLUDES)))) \
	-c \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	    $(PRIVATE_HOST_GLOBAL_CFLAGS) \
	 ) \
	$(1) \
	-MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef

define transform-host-c-to-o-no-deps
@echo "host C: $(PRIVATE_MODULE) <= $<"
$(call transform-host-c-or-s-to-o-no-deps, $(PRIVATE_CFLAGS) $(PRIVATE_CONLYFLAGS) $(PRIVATE_DEBUG_CFLAGS))
endef

define transform-host-s-to-o-no-deps
@echo "host asm: $(PRIVATE_MODULE) <= $<"
$(call transform-host-c-or-s-to-o-no-deps, $(PRIVATE_ASFLAGS))
endef

define transform-host-c-to-o
$(transform-host-c-to-o-no-deps)
$(transform-d-to-p)
endef

define transform-host-s-to-o
$(transform-host-s-to-o-no-deps)
$(transform-d-to-p)
endef


###########################################################
## Commands for running ar
###########################################################

define _concat-if-arg2-not-empty
$(if $(2),$(hide) $(1) $(2))
endef

# Split long argument list into smaller groups and call the command repeatedly
# Call the command at least once even if there are no arguments, as otherwise
# the output file won't be created.
#
# $(1): the command without arguments
# $(2): the arguments
define split-long-arguments
$(hide) $(1) $(wordlist 1,500,$(2))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 501,1000,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 1001,1500,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 1501,2000,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 2001,2500,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 2501,3000,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 3001,99999,$(2)))
endef

# $(1): the full path of the source static library.
define _extract-and-include-single-target-whole-static-lib
@echo "preparing StaticLib: $(PRIVATE_MODULE) [including $(1)]"
$(hide) ldir=$(PRIVATE_INTERMEDIATES_DIR)/WHOLE/$(basename $(notdir $(1)))_objs;\
    rm -rf $$ldir; \
    mkdir -p $$ldir; \
    filelist=; \
    for f in `$(TARGET_AR) t $(1)`; do \
        $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) p $(1) $$f > $$ldir/$$f; \
        filelist="$$filelist $$ldir/$$f"; \
    done ; \
    $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_ARFLAGS) \
        $(PRIVATE_ARFLAGS) $@ $$filelist

endef

define extract-and-include-target-whole-static-libs
$(foreach lib,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), \
    $(call _extract-and-include-single-target-whole-static-lib, $(lib)))
endef

# Explicitly delete the archive first so that ar doesn't
# try to add to an existing archive.
define transform-o-to-static-lib
@mkdir -p $(dir $@)
@rm -f $@
$(extract-and-include-target-whole-static-libs)
@echo "target StaticLib: $(PRIVATE_MODULE) ($@)"
$(call split-long-arguments,$($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_ARFLAGS) \
    $(PRIVATE_ARFLAGS) $@,$(filter %.o, $^))
endef

###########################################################
## Commands for running host ar
###########################################################

# $(1): the full path of the source static library.
define _extract-and-include-single-host-whole-static-lib
@echo "preparing StaticLib: $(PRIVATE_MODULE) [including $(1)]"
$(hide) ldir=$(PRIVATE_INTERMEDIATES_DIR)/WHOLE/$(basename $(notdir $(1)))_objs;\
    rm -rf $$ldir; \
    mkdir -p $$ldir; \
    filelist=; \
    for f in `$(HOST_AR) t $(1) | \grep '\.o$$'`; do \
        $(HOST_AR) p $(1) $$f > $$ldir/$$f; \
        filelist="$$filelist $$ldir/$$f"; \
    done ; \
    $(HOST_AR) $(HOST_GLOBAL_ARFLAGS) $(PRIVATE_ARFLAGS) $@ $$filelist

endef

define extract-and-include-host-whole-static-libs
$(foreach lib,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), \
    $(call _extract-and-include-single-host-whole-static-lib, $(lib)))
endef

# Explicitly delete the archive first so that ar doesn't
# try to add to an existing archive.
define transform-host-o-to-static-lib
@mkdir -p $(dir $@)
@rm -f $@
$(extract-and-include-host-whole-static-libs)
@echo "host StaticLib: $(PRIVATE_MODULE) ($@)"
$(call split-long-arguments,$(HOST_AR) $(HOST_GLOBAL_ARFLAGS) $(PRIVATE_ARFLAGS) $@,$(filter %.o, $^))
endef


###########################################################
## Commands for running gcc to link a shared library or package
###########################################################

# ld just seems to be so finicky with command order that we allow
# it to be overriden en-masse see combo/linux-arm.make for an example.
ifneq ($(HOST_CUSTOM_LD_COMMAND),true)
define transform-host-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
	-Wl,-rpath-link=$(HOST_OUT_INTERMEDIATE_LIBRARIES) \
	-Wl,-rpath,\$$ORIGIN/../lib \
	-shared -Wl,-soname,$(notdir $@) \
	$(HOST_GLOBAL_LD_DIRS) \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	   $(PRIVATE_HOST_GLOBAL_LDFLAGS) \
	) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_LDLIBS)
endef
endif

define transform-host-o-to-shared-lib
@mkdir -p $(dir $@)
@echo "host SharedLib: $(PRIVATE_MODULE) ($@)"
$(transform-host-o-to-shared-lib-inner)
endef

define transform-host-o-to-package
@mkdir -p $(dir $@)
@echo "host Package: $(PRIVATE_MODULE) ($@)"
$(transform-host-o-to-shared-lib-inner)
endef


###########################################################
## Commands for running gcc to link a shared library or package
###########################################################

#echo >$@.vers "{"; \
#echo >>$@.vers " global:"; \
#$(BUILD_SYSTEM)/filter_symbols.sh $(TARGET_NM) "  " ";" $(filter %.o,$^) | sort -u >>$@.vers; \
#echo >>$@.vers " local:"; \
#echo >>$@.vers "  *;"; \
#echo >>$@.vers "};"; \

#	-Wl,--version-script=$@.vers \

# ld just seems to be so finicky with command order that we allow
# it to be overriden en-masse see combo/linux-arm.make for an example.
ifneq ($(TARGET_CUSTOM_LD_COMMAND),true)
define transform-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	-Wl,-rpath-link=$(PRIVATE_TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	-Wl,-rpath,\$$ORIGIN/../lib \
	-shared -Wl,-soname,$(notdir $@) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_LDLIBS)
endef
endif

define transform-o-to-shared-lib
@mkdir -p $(dir $@)
@echo "target SharedLib: $(PRIVATE_MODULE) ($@)"
$($(PRIVATE_2ND_ARCH_VAR_PREFIX)transform-o-to-shared-lib-inner)
endef


###########################################################
## Commands for filtering a target executable or library
###########################################################

ifneq ($(TARGET_BUILD_VARIANT),user)
  TARGET_STRIP_EXTRA = && $(PRIVATE_OBJCOPY) --add-gnu-debuglink=$< $@
  TARGET_STRIP_KEEP_SYMBOLS_EXTRA = --add-gnu-debuglink=$<
endif

define transform-to-stripped
@mkdir -p $(dir $@)
@echo "target Strip: $(PRIVATE_MODULE) ($@)"
$(hide) $(PRIVATE_STRIP) --strip-all $< -o $@ $(TARGET_STRIP_EXTRA)
endef

define transform-to-stripped-keep-symbols
@mkdir -p $(dir $@)
@echo "target Strip (keep symbols): $(PRIVATE_MODULE) ($@)"
$(hide) $(PRIVATE_OBJCOPY) \
    `$(PRIVATE_READELF) -S $< | awk '/.debug_/ {print "-R " $$2}' | xargs` \
    $(TARGET_STRIP_KEEP_SYMBOLS_EXTRA) $< $@
endef


###########################################################
## Commands for running gcc to link an executable
###########################################################

ifneq ($(TARGET_CUSTOM_LD_COMMAND),true)
define transform-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	-Wl,-rpath-link=$(PRIVATE_TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	-Wl,-rpath,\$$ORIGIN/../lib \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_LDLIBS)
endef
endif

define transform-o-to-executable
@mkdir -p $(dir $@)
@echo "target Executable: $(PRIVATE_MODULE) ($@)"
$($(PRIVATE_2ND_ARCH_VAR_PREFIX)transform-o-to-executable-inner)
endef


###########################################################
## Commands for running gcc to link a statically linked
## executable.  In practice, we only use this on arm, so
## the other platforms don't have the
## transform-o-to-static-executable defined
###########################################################

ifneq ($(TARGET_CUSTOM_LD_COMMAND),true)
define transform-o-to-static-executable-inner
endef
endif

define transform-o-to-static-executable
@mkdir -p $(dir $@)
@echo "target StaticExecutable: $(PRIVATE_MODULE) ($@)"
$($(PRIVATE_2ND_ARCH_VAR_PREFIX)transform-o-to-static-executable-inner)
endef


###########################################################
## Commands for running gcc to link a host executable
###########################################################

ifneq ($(HOST_CUSTOM_LD_COMMAND),true)
define transform-host-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-Wl,-rpath-link=$(HOST_OUT_INTERMEDIATE_LIBRARIES) \
	-Wl,-rpath,\$$ORIGIN/../lib \
	$(HOST_GLOBAL_LD_DIRS) \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
		$(PRIVATE_HOST_GLOBAL_LDFLAGS) \
		-fPIE -pie \
	) \
	$(PRIVATE_LDFLAGS) \
	-o $@ \
	$(PRIVATE_LDLIBS)
endef
endif

define transform-host-o-to-executable
@mkdir -p $(dir $@)
@echo "host Executable: $(PRIVATE_MODULE) ($@)"
$(transform-host-o-to-executable-inner)
endef


###########################################################
## Commands for copying files
###########################################################

# Define a rule to copy a header.  Used via $(eval) by copy_headers.make.
# $(1): source header
# $(2): destination header
define copy-one-header
$(2): $(1)
	@echo "Header: $$@"
	$$(copy-file-to-new-target-with-cp)
endef

# Define a rule to copy a file.  For use via $(eval).
# $(1): source file
# $(2): destination file
define copy-one-file
$(2): $(1) | $(ACP)
	@echo "Copy: $$@"
	$$(copy-file-to-target)
endef

# Copies many files.
# $(1): The files to copy.  Each entry is a ':' separated src:dst pair
# Evaluates to the list of the dst files (ie suitable for a dependency list)
define copy-many-files
$(foreach f, $(1), $(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(eval _cmf_dest := $(word 2,$(_cmf_tuple))) \
    $(eval $(call copy-one-file,$(_cmf_src),$(_cmf_dest))) \
    $(_cmf_dest)))
endef

# Copy the file only if it's a well-formed xml file. For use via $(eval).
# $(1): source file
# $(2): destination file, must end with .xml.
define copy-xml-file-checked
$(2): $(1) | $(ACP)
	@echo "Copy xml: $$@"
	$(hide) xmllint $$< >/dev/null  # Don't print the xml file to stdout.
	$$(copy-file-to-target)
endef

# The -t option to acp and the -p option to cp is
# required for OSX.  OSX has a ridiculous restriction
# where it's an error for a .a file's modification time
# to disagree with an internal timestamp, and this
# macro is used to install .a files (among other things).

# Copy a single file from one place to another,
# preserving permissions and overwriting any existing
# file.
# We disable the "-t" option for acp cannot handle
# high resolution timestamp correctly on file systems like ext4.
# Therefore copy-file-to-target is the same as copy-file-to-new-target.
define copy-file-to-target
@mkdir -p $(dir $@)
$(hide) $(ACP) -fp $< $@
endef

# The same as copy-file-to-target, but use the local
# cp command instead of acp.
define copy-file-to-target-with-cp
@mkdir -p $(dir $@)
$(hide) cp -fp $< $@
endef

# The same as copy-file-to-target, but use the zipalign tool to do so.
define copy-file-to-target-with-zipalign
@mkdir -p $(dir $@)
$(hide) $(ZIPALIGN) -f 4 $< $@
endef

# The same as copy-file-to-target, but strip out "# comment"-style
# comments (for config files and such).
define copy-file-to-target-strip-comments
@mkdir -p $(dir $@)
$(hide) sed -e 's/#.*$$//' -e 's/[ \t]*$$//' -e '/^$$/d' < $< > $@
endef

# The same as copy-file-to-target, but don't preserve
# the old modification time.
define copy-file-to-new-target
@mkdir -p $(dir $@)
$(hide) $(ACP) -fp $< $@
endef

# The same as copy-file-to-new-target, but use the local
# cp command instead of acp.
define copy-file-to-new-target-with-cp
@mkdir -p $(dir $@)
$(hide) cp -f $< $@
endef

# Copy a prebuilt file to a target location.
define transform-prebuilt-to-target
@echo "$(if $(PRIVATE_IS_HOST_MODULE),host,target) Prebuilt: $(PRIVATE_MODULE) ($@)"
$(copy-file-to-target)
endef

# Copy a prebuilt file to a target location, using zipalign on it.
define transform-prebuilt-to-target-with-zipalign
@echo "$(if $(PRIVATE_IS_HOST_MODULE),host,target) Prebuilt APK: $(PRIVATE_MODULE) ($@)"
$(copy-file-to-target-with-zipalign)
endef

# Copy a prebuilt file to a target location, stripping "# comment" comments.
define transform-prebuilt-to-target-strip-comments
@echo "$(if $(PRIVATE_IS_HOST_MODULE),host,target) Prebuilt: $(PRIVATE_MODULE) ($@)"
$(copy-file-to-target-strip-comments)
endef

###########################################################
## On some platforms (MacOS), after copying a static
## library, ranlib must be run to update an internal
## timestamp!?!?!
###########################################################

ifeq ($(HOST_RUN_RANLIB_AFTER_COPYING),true)
define transform-host-ranlib-copy-hack
    $(hide) ranlib $@ || true
endef
else
define transform-host-ranlib-copy-hack
@true
endef
endif

ifeq ($(TARGET_RUN_RANLIB_AFTER_COPYING),true)
define transform-ranlib-copy-hack
    $(hide) ranlib $@
endef
else
define transform-ranlib-copy-hack
@true
endef
endif


###########################################################
## Stuff source generated from one-off tools
###########################################################

define transform-generated-source
@echo "target Generated: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(hide) $(PRIVATE_CUSTOM_TOOL)
endef


###########################################################
## Assertions about attributes of the target
###########################################################

# $(1): The file to check
ifndef get-file-size
$(error HOST_OS must define get-file-size)
endif

# Convert a partition data size (eg, as reported in /proc/mtd) to the
# size of the image used to flash that partition (which includes a
# spare area for each page).
# $(1): the partition data size
define image-size-from-data-size
$(strip $(eval _isfds_value := $$(shell echo $$$$(($(1) / $(BOARD_NAND_PAGE_SIZE) * \
  ($(BOARD_NAND_PAGE_SIZE)+$(BOARD_NAND_SPARE_SIZE))))))\
$(if $(filter 0, $(_isfds_value)),$(shell echo $$(($(BOARD_NAND_PAGE_SIZE)+$(BOARD_NAND_SPARE_SIZE)))),$(_isfds_value))\
$(eval _isfds_value :=))
endef

# $(1): The file(s) to check (often $@)
# $(2): The maximum total image size, in decimal bytes
# $(3): the type of filesystem "yaffs" or "raw"
#
# If $(2) is empty, evaluates to "true"
#
# Reserve bad blocks.  Make sure that MAX(1% of partition size, 2 blocks)
# is left over after the image has been flashed.  Round the 1% up to the
# next whole flash block size.
define assert-max-file-size
$(if $(2), \
  size=$$(for i in $(1); do $(call get-file-size,$$i); echo +; done; echo 0); \
  total=$$(( $$( echo "$$size" ) )); \
  printname=$$(echo -n "$(1)" | tr " " +); \
  img_blocksize=$(call image-size-from-data-size,$(BOARD_FLASH_BLOCK_SIZE)); \
  if [ "$(3)" == "yaffs" ]; then \
    reservedblocks=8; \
  else \
    reservedblocks=0; \
  fi; \
  twoblocks=$$((img_blocksize * 2)); \
  onepct=$$((((($(2) / 100) - 1) / img_blocksize + 1) * img_blocksize)); \
  reserve=$$(((twoblocks > onepct ? twoblocks : onepct) + \
               reservedblocks * img_blocksize)); \
  maxsize=$$(($(2) - reserve)); \
  echo "$$printname maxsize=$$maxsize blocksize=$$img_blocksize total=$$total reserve=$$reserve"; \
  if [ "$$total" -gt "$$maxsize" ]; then \
    echo "error: $$printname too large ($$total > [$(2) - $$reserve])"; \
    false; \
  elif [ "$$total" -gt $$((maxsize - 32768)) ]; then \
    echo "WARNING: $$printname approaching size limit ($$total now; limit $$maxsize)"; \
  fi \
 , \
  true \
 )
endef

# Like assert-max-file-size, but the second argument is a partition
# size, which we'll convert to a max image size before checking it
# against the files.
#
# $(1): The file(s) to check (often $@)
# $(2): The partition size.
define assert-max-image-size
$(if $(2), \
  $(call assert-max-file-size,$(1),$(call image-size-from-data-size,$(2))), \
  true)
endef

###########################################################
## Expand a module name list with REQUIRED modules
###########################################################
# $(1): The variable name that holds the initial module name list.
#       the variable will be modified to hold the expanded results.
# $(2): The initial module name list.
# Returns empty string (maybe with some whitespaces).
define expand-required-modules
$(eval _erm_new_modules := $(sort $(filter-out $($(1)),\
  $(foreach m,$(2),$(ALL_MODULES.$(m).REQUIRED)))))\
$(if $(_erm_new_modules),$(eval $(1) += $(_erm_new_modules))\
  $(call expand-required-modules,$(1),$(_erm_new_modules)))
endef


## Whether to build from source if prebuilt alternative exists
###########################################################
# $(1): module name
# $(2): LOCAL_PATH
# Expands to empty string if not from source.
ifeq (true,$(VMWORKS_BUILD_FROM_SOURCE))
define if-build-from-source
true
endef
else
define if-build-from-source
endef
endif

# Include makefile $(1) if build from source for module $(2)
# $(1): the makefile to include
# $(2): module name
# $(3): LOCAL_PATH
define include-if-build-from-source
$(if $(call if-build-from-source,$(2),$(3)),$(eval include $(1)))
endef

## Return the arch for the source file of a prebuilt
# $(1) the list of archs supported by the prebuilt
define get-prebuilt-src-arch
$(strip $(if $(filter $(TARGET_ARCH),$(1)),$(TARGET_ARCH),\
  $(if $(filter $(TARGET_2ND_ARCH),$(1)),$(TARGET_2ND_ARCH))))
endef

###########################################################
## Other includes
###########################################################

# -----------------------------------------------------------------
# Rules and functions to help copy important files to DIST_DIR
# when requested.
include $(BUILD_SYSTEM)/distdir.mk

# broken:
#	$(foreach file,$^,$(if $(findstring,.a,$(suffix $file)),-l$(file),$(file)))

###########################################################
## Misc notes
###########################################################

#DEPDIR = .deps
#df = $(DEPDIR)/$(*F)

#SRCS = foo.c bar.c ...

#%.o : %.c
#	@$(MAKEDEPEND); \
#	  cp $(df).d $(df).P; \
#	  sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
#	      -e '/^$$/ d' -e 's/$$/ :/' < $(df).d >> $(df).P; \
#	  rm -f $(df).d
#	$(COMPILE.c) -o $@ $<

#-include $(SRCS:%.c=$(DEPDIR)/%.P)


#%.o : %.c
#	$(COMPILE.c) -MD -o $@ $<
#	@cp $*.d $*.P; \
#	  sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
#	      -e '/^$$/ d' -e 's/$$/ :/' < $*.d >> $*.P; \
#	  rm -f $*.d
