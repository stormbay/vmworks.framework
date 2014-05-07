#
# Functions for including vmWorksProducts.mk files
# PRODUCT_MAKEFILES is set up in vmWorksProducts.mks.
# Format of PRODUCT_MAKEFILES:
# <product_name>:<path_to_the_product_makefile>
# If the <product_name> is the same as the base file name (without dir
# and the .mk suffix) of the product makefile, "<product_name>:" can be
# omitted.

#
# Returns the list of all vmWorksProducts.mk files.
# $(call ) isn't necessary.
#
define _find-vmworks-products-files
$(shell test -d platform && find platform -maxdepth 6 -name vmWorksProducts.mk)
endef

#
# Returns the sorted concatenation of PRODUCT_MAKEFILES
# variables set in the given vmWorksProducts.mk files.
# $(1): the list of vmWorksProducts.mk files.
#
define get-product-makefiles
$(sort \
  $(foreach f,$(1), \
    $(eval PRODUCT_MAKEFILES :=) \
    $(eval LOCAL_DIR := $(patsubst %/,%,$(dir $(f)))) \
    $(eval include $(f)) \
    $(PRODUCT_MAKEFILES) \
   ) \
  $(eval PRODUCT_MAKEFILES :=) \
  $(eval LOCAL_DIR :=) \
 )
endef

#
# Returns the sorted concatenation of all PRODUCT_MAKEFILES
# variables set in all vmProducts.mk files.
# $(call ) isn't necessary.
#
define get-all-product-makefiles
$(call get-product-makefiles,$(_find-vmworks-products-files)) \
$(shell echo --- debug print --- )	\
$(shell echo $(_find-vmworks-products-files))
endef

#
# Functions for including product makefiles
#

_product_var_list := \
    PRODUCT_NAME \
    PRODUCT_MODEL \
    PRODUCT_LOCALES \
    PRODUCT_PACKAGES \
    PRODUCT_PACKAGES_DEBUG \
    PRODUCT_PACKAGES_ENG \
    PRODUCT_PACKAGES_TESTS \
    PRODUCT_DEVICE \
    PRODUCT_MANUFACTURER \
    PRODUCT_BRAND \
    PRODUCT_PROPERTY_OVERRIDES \
    PRODUCT_DEFAULT_PROPERTY_OVERRIDES \
    PRODUCT_CHARACTERISTICS \
    PRODUCT_COPY_FILES \
    PRODUCT_PACKAGE_OVERLAYS \
    DEVICE_PACKAGE_OVERLAYS \
    PRODUCT_TAGS \
    PRODUCT_RUNTIMES \

define dump-product
$(info ==== $(1) ====)\
$(foreach v,$(_product_var_list),\
$(info PRODUCTS.$(1).$(v) := $(PRODUCTS.$(1).$(v))))\
$(info --------)
endef

define dump-products
$(foreach p,$(PRODUCTS),$(call dump-product,$(p)))
endef

#
# $(1): product to inherit
#
# Does three things:
#  1. Inherits all of the variables from $1.
#  2. Records the inheritance in the .INHERITS_FROM variable
#  3. Records that we've visited this node, in ALL_PRODUCTS
#
define inherit-product
  $(foreach v,$(_product_var_list), \
      $(eval $(v) := $($(v)) $(INHERIT_TAG)$(strip $(1)))) \
  $(eval inherit_var := \
      PRODUCTS.$(strip $(word 1,$(_include_stack))).INHERITS_FROM) \
  $(eval $(inherit_var) := $(sort $($(inherit_var)) $(strip $(1)))) \
  $(eval inherit_var:=) \
  $(eval ALL_PRODUCTS := $(sort $(ALL_PRODUCTS) $(word 1,$(_include_stack))))
endef


#
# Do inherit-product only if $(1) exists
#
define inherit-product-if-exists
  $(if $(wildcard $(1)),$(call inherit-product,$(1)),)
endef

#
# $(1): product makefile list
#
#TODO: check to make sure that products have all the necessary vars defined
define import-products
$(call import-nodes,PRODUCTS,$(1),$(_product_var_list))
endef


#
# Does various consistency checks on all of the known products.
# Takes no parameters, so $(call ) is not necessary.
#
define check-all-products
$(if ,, \
  $(eval _cap_names :=) \
  $(foreach p,$(PRODUCTS), \
    $(eval pn := $(strip $(PRODUCTS.$(p).PRODUCT_NAME))) \
    $(if $(pn),,$(error $(p): PRODUCT_NAME must be defined.)) \
    $(if $(filter $(pn),$(_cap_names)), \
      $(error $(p): PRODUCT_NAME must be unique; "$(pn)" already used by $(strip \
          $(foreach \
            pp,$(PRODUCTS),
              $(if $(filter $(pn),$(PRODUCTS.$(pp).PRODUCT_NAME)), \
                $(pp) \
               ))) \
       ) \
     ) \
    $(eval _cap_names += $(pn)) \
    $(if $(call is-c-identifier,$(pn)),, \
      $(error $(p): PRODUCT_NAME must be a valid C identifier, not "$(pn)") \
     ) \
    $(eval pb := $(strip $(PRODUCTS.$(p).PRODUCT_BRAND))) \
    $(if $(pb),,$(error $(p): PRODUCT_BRAND must be defined.)) \
    $(foreach cf,$(strip $(PRODUCTS.$(p).PRODUCT_COPY_FILES)), \
      $(if $(filter 2 3,$(words $(subst :,$(space),$(cf)))),, \
        $(error $(p): malformed COPY_FILE "$(cf)") \
       ) \
     ) \
   ) \
)
endef


#
# Returns the product makefile path for the product with the provided name
#
# $(1): short product name like "generic"
#
define _resolve-short-product-name
  $(eval pn := $(strip $(1)))
  $(eval p := \
      $(foreach p,$(PRODUCTS), \
          $(if $(filter $(pn),$(PRODUCTS.$(p).PRODUCT_NAME)), \
            $(p) \
       )) \
   )
  $(eval p := $(sort $(p)))
  $(if $(filter 1,$(words $(p))), \
    $(p), \
    $(if $(filter 0,$(words $(p))), \
      $(error No matches for product "$(pn)"), \
      $(error Product "$(pn)" ambiguous: matches $(p)) \
    ) \
  )
endef
define resolve-short-product-name
$(strip $(call _resolve-short-product-name,$(1)))
endef


_product_stash_var_list := $(_product_var_list) \
	PRODUCT_BOOTCLASSPATH \
	TARGET_ARCH \
	TARGET_ARCH_VARIANT \
	TARGET_CPU_VARIANT \
	TARGET_BOARD_PLATFORM \
	TARGET_BOARD_PLATFORM_GPU \
	TARGET_BOARD_KERNEL_HEADERS \
	TARGET_DEVICE_KERNEL_HEADERS \
	TARGET_PRODUCT_KERNEL_HEADERS \
	TARGET_BOOTLOADER_BOARD_NAME \
	TARGET_COMPRESS_MODULE_SYMBOLS \
	TARGET_NO_BOOTLOADER \
	TARGET_NO_KERNEL \
	TARGET_NO_RECOVERY \
	TARGET_NO_RADIOIMAGE \
	TARGET_HARDWARE_3D \
	TARGET_PROVIDES_INIT_RC \
	TARGET_CPU_ABI \
	TARGET_CPU_ABI2 \
	TARGET_CPU_SMP \


_product_stash_var_list += \
	BOARD_KERNEL_CMDLINE \
	BOARD_KERNEL_BASE \
	BOARD_BOOTIMAGE_PARTITION_SIZE \
	BOARD_SYSTEMIMAGE_PARTITION_SIZE \
	BOARD_USERDATAIMAGE_PARTITION_SIZE \
	BOARD_FLASH_BLOCK_SIZE \
	BOARD_SYSTEMIMAGE_PARTITION_SIZE \
	BOARD_INSTALLER_CMDLINE \


_product_stash_var_list +=

#
# Stash values of the variables in _product_stash_var_list.
# $(1): Renamed prefix
#
define stash-product-vars
$(foreach v,$(_product_stash_var_list), \
        $(eval $(strip $(1))_$(call rot13,$(v)):=$$($$(v))) \
 )
endef

#
# Assert that the the variable stashed by stash-product-vars remains untouched.
# $(1): The prefix as supplied to stash-product-vars
#
define assert-product-vars
$(strip \
  $(eval changed_variables:=)
  $(foreach v,$(_product_stash_var_list), \
    $(if $(call streq,$($(v)),$($(strip $(1))_$(call rot13,$(v)))),, \
        $(eval $(warning $(v) has been modified: $($(v)))) \
        $(eval $(warning previous value: $($(strip $(1))_$(call rot13,$(v))))) \
        $(eval changed_variables := $(changed_variables) $(v))) \
   ) \
  $(if $(changed_variables),\
    $(eval $(error The following variables have been changed: $(changed_variables))),)
)
endef

define add-to-product-copy-files-if-exists
$(if $(wildcard $(word 1,$(subst :, ,$(1)))),$(1))
endef