# Put some miscellaneous rules here

# HACK: clear LOCAL_PATH from including last build target before calling
# intermedites-dir-for
LOCAL_PATH := $(BUILD_SYSTEM)

# Pick a reasonable string to use to identify files.
ifneq "" "$(filter eng.%,$(BUILD_NUMBER))"
  # BUILD_NUMBER has a timestamp in it, which means that
  # it will change every time.  Pick a stable value.
  FILE_NAME_TAG := eng.$(USER)
else
  FILE_NAME_TAG := $(BUILD_NUMBER)
endif

is_tests_build := $(filter tests,$(MAKECMDGOALS))

# -----------------------------------------------------------------
# Define rules to copy PRODUCT_COPY_FILES defined by the product.
# PRODUCT_COPY_FILES contains words like <source file>:<dest file>[:<owner>].
# <dest file> is relative to $(PRODUCT_OUT), so it should look like,
# e.g., "system/etc/file.xml".
# The filter part means "only eval the copy-one-file rule if this
# src:dest pair is the first one to match the same dest"

# filter out the duplicate <source file>:<dest file> pairs.
unique_product_copy_files_pairs :=
$(foreach cf,$(PRODUCT_COPY_FILES), \
    $(if $(filter $(unique_product_copy_files_pairs),$(cf)),,\
        $(eval unique_product_copy_files_pairs += $(cf))))
unique_product_copy_files_destinations :=
$(foreach cf,$(unique_product_copy_files_pairs), \
    $(eval _src := $(call word-colon,1,$(cf))) \
    $(eval _dest := $(call word-colon,2,$(cf))) \
    $(if $(filter $(unique_product_copy_files_destinations),$(_dest)), \
        $(info PRODUCT_COPY_FILES $(cf) ignored.), \
        $(eval _fulldest := $(call append-path,$(PRODUCT_OUT),$(_dest))) \
        $(if $(filter %.xml,$(_dest)),\
            $(eval $(call copy-xml-file-checked,$(_src),$(_fulldest))),\
            $(eval $(call copy-one-file,$(_src),$(_fulldest)))) \
        $(eval ALL_DEFAULT_INSTALLED_MODULES += $(_fulldest)) \
        $(eval unique_product_copy_files_destinations += $(_dest))))
unique_product_copy_files_pairs :=
unique_product_copy_files_destinations :=

# -----------------------------------------------------------------
# default.prop
INSTALLED_DEFAULT_PROP_TARGET := $(TARGET_ROOT_OUT)/default.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_DEFAULT_PROP_TARGET)
ADDITIONAL_DEFAULT_PROPERTIES := \
    $(call collapse-pairs, $(ADDITIONAL_DEFAULT_PROPERTIES))
ADDITIONAL_DEFAULT_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_DEFAULT_PROPERTY_OVERRIDES))
ADDITIONAL_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(ADDITIONAL_DEFAULT_PROPERTIES),=)

$(INSTALLED_DEFAULT_PROP_TARGET):
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo "#" > $@; \
	        echo "# ADDITIONAL_DEFAULT_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(ADDITIONAL_DEFAULT_PROPERTIES), \
		echo "$(line)" >> $@;)
	build/tools/post_process_props.py $@

# -----------------------------------------------------------------
# build.prop
INSTALLED_BUILD_PROP_TARGET := $(TARGET_OUT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_BUILD_PROP_TARGET)
ADDITIONAL_BUILD_PROPERTIES := \
    $(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES))
ADDITIONAL_BUILD_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(ADDITIONAL_BUILD_PROPERTIES),=)

# A list of arbitrary tags describing the build configuration.
# Force ":=" so we can use +=
BUILD_VERSION_TAGS := $(BUILD_VERSION_TAGS)
ifeq ($(TARGET_BUILD_TYPE),debug)
  BUILD_VERSION_TAGS += debug
endif
BUILD_VERSION_TAGS := $(subst $(space),$(comma),$(sort $(BUILD_VERSION_TAGS)))

# A human-readable string that descibes this build in detail.
build_desc := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT) $(PLATFORM_VERSION) $(BUILD_ID) $(BUILD_NUMBER) $(BUILD_VERSION_TAGS)
$(INSTALLED_BUILD_PROP_TARGET): PRIVATE_BUILD_DESC := $(build_desc)

# The string used to uniquely identify this build;
ifeq (,$(strip $(BUILD_FINGERPRINT)))
  BUILD_FINGERPRINT := $(PRODUCT_BRAND)/$(TARGET_PRODUCT)/$(TARGET_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
endif
ifneq ($(words $(BUILD_FINGERPRINT)),1)
  $(error BUILD_FINGERPRINT cannot contain spaces: "$(BUILD_FINGERPRINT)")
endif

# Display parameters shown under Settings -> About Phone
ifeq ($(TARGET_BUILD_VARIANT),user)
  # User builds should show:
  # release build number or branch.buld_number non-release builds

  # Dev. branches should have DISPLAY_BUILD_NUMBER set
  ifeq "true" "$(DISPLAY_BUILD_NUMBER)"
    BUILD_DISPLAY_ID := $(BUILD_ID).$(BUILD_NUMBER) $(BUILD_KEYS)
  else
    BUILD_DISPLAY_ID := $(BUILD_ID) $(BUILD_KEYS)
  endif
else
  # Non-user builds should show detailed build information
  BUILD_DISPLAY_ID := $(build_desc)
endif

BUILDINFO_SH := build/tools/buildinfo.sh

ifdef TARGET_SYSTEM_PROP
system_prop_file := $(TARGET_SYSTEM_PROP)
else
system_prop_file := $(wildcard $(TARGET_DEVICE_DIR)/system.prop)
endif

$(INSTALLED_BUILD_PROP_TARGET): $(BUILDINFO_SH) $(INTERNAL_BUILD_ID_MAKEFILE) $(BUILD_SYSTEM)/version_defaults.mk $(system_prop_file)
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) TARGET_BUILD_TYPE="$(TARGET_BUILD_VARIANT)" \
			TARGET_DEVICE="$(TARGET_DEVICE)" \
			PRODUCT_NAME="$(TARGET_PRODUCT)" \
			PRODUCT_BRAND="$(PRODUCT_BRAND)" \
			PRODUCT_DEFAULT_LANGUAGE="$(call default-locale-language,$(PRODUCT_LOCALES))" \
			PRODUCT_DEFAULT_REGION="$(call default-locale-region,$(PRODUCT_LOCALES))" \
			PRODUCT_MODEL="$(PRODUCT_MODEL)" \
			PRODUCT_MANUFACTURER="$(PRODUCT_MANUFACTURER)" \
			PRIVATE_BUILD_DESC="$(PRIVATE_BUILD_DESC)" \
			BUILD_ID="$(BUILD_ID)" \
			BUILD_DISPLAY_ID="$(BUILD_DISPLAY_ID)" \
			BUILD_NUMBER="$(BUILD_NUMBER)" \
			PLATFORM_VERSION="$(PLATFORM_VERSION)" \
			PLATFORM_VERSION_CODENAME="$(PLATFORM_VERSION_CODENAME)" \
			BUILD_VERSION_TAGS="$(BUILD_VERSION_TAGS)" \
			TARGET_BOOTLOADER_BOARD_NAME="$(TARGET_BOOTLOADER_BOARD_NAME)" \
			BUILD_FINGERPRINT="$(BUILD_FINGERPRINT)" \
			TARGET_BOARD_PLATFORM="$(TARGET_BOARD_PLATFORM)" \
			TARGET_CPU_ABI_LIST="$(TARGET_CPU_ABI_LIST)" \
			TARGET_CPU_ABI="$(TARGET_CPU_ABI)" \
			TARGET_CPU_ABI2="$(TARGET_CPU_ABI2)" \
	        bash $(BUILDINFO_SH) > $@
	$(hide) $(foreach file,$(system_prop_file), \
		if [ -f "$(file)" ]; then \
			echo "#" >> $@; \
			echo Target buildinfo from: "$(file)"; \
			echo "# from $(file)" >> $@; \
			echo "#" >> $@; \
			cat $(file) >> $@; \
		fi;)
	$(if $(ADDITIONAL_BUILD_PROPERTIES), \
		$(hide) echo >> $@; \
		        echo "#" >> $@; \
		        echo "# ADDITIONAL_BUILD_PROPERTIES" >> $@; \
		        echo "#" >> $@; )
	$(hide) $(foreach line,$(ADDITIONAL_BUILD_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) build/tools/post_process_props.py $@

build_desc :=


# -----------------------------------------------------------------
# package stats
PACKAGE_STATS_FILE := $(PRODUCT_OUT)/package-stats.txt
PACKAGES_TO_STAT := \
    $(sort $(filter $(TARGET_OUT)/% $(TARGET_OUT_DATA)/%, \
	$(filter %.jar %.apk, $(ALL_DEFAULT_INSTALLED_MODULES))))
$(PACKAGE_STATS_FILE): $(PACKAGES_TO_STAT)
	@echo Package stats: $@
	@mkdir -p $(dir $@)
	$(hide) rm -f $@
	$(hide) build/tools/dump-package-stats $^ > $@

.PHONY: package-stats
package-stats: $(PACKAGE_STATS_FILE)


# -----------------------------------------------------------------
# module info file
ifdef CREATE_MODULE_INFO_FILE
  MODULE_INFO_FILE := $(PRODUCT_OUT)/module-info.txt
  $(info Generating $(MODULE_INFO_FILE)...)
  $(shell rm -f $(MODULE_INFO_FILE))
  $(foreach m,$(ALL_MODULES), \
    $(shell echo "NAME=\"$(m)\"" \
	"PATH=\"$(strip $(ALL_MODULES.$(m).PATH))\"" \
	"TAGS=\"$(strip $(filter-out _%,$(ALL_MODULES.$(m).TAGS)))\"" \
	"BUILT=\"$(strip $(ALL_MODULES.$(m).BUILT))\"" \
	"INSTALLED=\"$(strip $(ALL_MODULES.$(m).INSTALLED))\"" >> $(MODULE_INFO_FILE)))
endif


# Rules that need to be present for the all targets, even
# if they don't do anything.
.PHONY: systemimage
systemimage:


# #################################################################
# Targets for boot/OS images
# #################################################################
ifneq ($(strip $(TARGET_NO_BOOTLOADER)),true)
  INSTALLED_BOOTLOADER_MODULE := $(PRODUCT_OUT)/bootloader
  ifeq ($(strip $(TARGET_BOOTLOADER_IS_2ND)),true)
    INSTALLED_2NDBOOTLOADER_TARGET := $(PRODUCT_OUT)/2ndbootloader
  else
    INSTALLED_2NDBOOTLOADER_TARGET :=
  endif
else
  INSTALLED_BOOTLOADER_MODULE :=
  INSTALLED_2NDBOOTLOADER_TARGET :=
endif # TARGET_NO_BOOTLOADER
ifneq ($(strip $(TARGET_NO_KERNEL)),true)
  INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel.bin
else
  INSTALLED_KERNEL_TARGET :=
endif

# -----------------------------------------------------------------
# the ramdisk
INTERNAL_RAMDISK_FILES := $(filter $(TARGET_ROOT_OUT)/%, \
	$(ALL_PREBUILT) \
	$(ALL_COPIED_HEADERS) \
	$(ALL_GENERATED_SOURCES) \
	$(ALL_DEFAULT_INSTALLED_MODULES))

BUILT_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk.img

# We just build this directly to the install location.
INSTALLED_RAMDISK_TARGET := $(BUILT_RAMDISK_TARGET)
$(INSTALLED_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_RAMDISK_FILES) | $(MINIGZIP)
	$(call pretty,"Target ram disk: $@")
	@cp -af $(PRODUCT_ROOT_SOURCE)/* $(TARGET_ROOT_OUT)/
	$(hide) $(MKBOOTFS) $(TARGET_ROOT_OUT) | $(MINIGZIP) > $@


ifneq ($(strip $(TARGET_NO_KERNEL)),true)

# -----------------------------------------------------------------
# the boot image, which is a collection of other images.
INTERNAL_BOOTIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
	--kernel $(INSTALLED_KERNEL_TARGET) \
	--ramdisk $(INSTALLED_RAMDISK_TARGET)

INTERNAL_BOOTIMAGE_FILES := $(filter-out --%,$(INTERNAL_BOOTIMAGE_ARGS))

BOARD_KERNEL_CMDLINE := $(strip $(BOARD_KERNEL_CMDLINE))
ifdef BOARD_KERNEL_CMDLINE
  INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(BOARD_KERNEL_CMDLINE)"
endif

BOARD_KERNEL_BASE := $(strip $(BOARD_KERNEL_BASE))
ifdef BOARD_KERNEL_BASE
  INTERNAL_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif

BOARD_KERNEL_PAGESIZE := $(strip $(BOARD_KERNEL_PAGESIZE))
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img

ifeq ($(TARGET_BOOTIMAGE_USE_EXT2),true)
tmp_dir_for_image := $(call intermediates-dir-for,EXECUTABLES,boot_img)/bootimg
INTERNAL_BOOTIMAGE_ARGS += --tmpdir $(tmp_dir_for_image)
INTERNAL_BOOTIMAGE_ARGS += --genext2fs $(MKEXT2IMG)
$(INSTALLED_BOOTIMAGE_TARGET): $(MKEXT2IMG) $(INTERNAL_BOOTIMAGE_FILES)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKEXT2BOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) --output $@

else # TARGET_BOOTIMAGE_USE_EXT2 != true

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE),raw)

endif # TARGET_BOOTIMAGE_USE_EXT2

else	# TARGET_NO_KERNEL
# HACK: The top-level targets depend on the bootimage.  Not all targets
# can produce a bootimage, though, and emulator targets need the ramdisk
# instead.  Fake it out by calling the ramdisk the bootimage.
# TODO: make the emulator use bootimages, and make mkbootimg accept
#       kernel-less inputs.
INSTALLED_BOOTIMAGE_TARGET := $(INSTALLED_RAMDISK_TARGET)
endif


# #################################################################
# Targets for user images
# #################################################################

INTERNAL_USERIMAGES_EXT_VARIANT :=
ifeq ($(TARGET_USERIMAGES_USE_EXT2),true)
INTERNAL_USERIMAGES_USE_EXT := true
INTERNAL_USERIMAGES_EXT_VARIANT := ext2
else
ifeq ($(TARGET_USERIMAGES_USE_EXT3),true)
INTERNAL_USERIMAGES_USE_EXT := true
INTERNAL_USERIMAGES_EXT_VARIANT := ext3
else
ifeq ($(TARGET_USERIMAGES_USE_EXT4),true)
INTERNAL_USERIMAGES_USE_EXT := true
INTERNAL_USERIMAGES_EXT_VARIANT := ext4
endif
endif
endif

ifneq (true,$(TARGET_USERIMAGES_SPARSE_EXT_DISABLED))
  INTERNAL_USERIMAGES_SPARSE_EXT_FLAG := -s
endif

ifeq ($(INTERNAL_USERIMAGES_USE_EXT),true)
INTERNAL_USERIMAGES_DEPS := $(MKEXTUSERIMG) $(MAKE_EXT4FS) $(SIMG2IMG) $(E2FSCK)
else
INTERNAL_USERIMAGES_DEPS := $(MKYAFFS2)
endif
INTERNAL_USERIMAGES_BINARY_PATHS := $(sort $(dir $(INTERNAL_USERIMAGES_DEPS)))

# $(1): the path of the output dictionary file
# $(2): additional "key=value" pairs to append to the dictionary file.
define generate-userimage-prop-dictionary
$(if $(INTERNAL_USERIMAGES_EXT_VARIANT),$(hide) echo "fs_type=$(INTERNAL_USERIMAGES_EXT_VARIANT)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_PARTITION_SIZE),$(hide) echo "system_size=$(BOARD_SYSTEMIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_USERDATAIMAGE_PARTITION_SIZE),$(hide) echo "userdata_size=$(BOARD_USERDATAIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(INTERNAL_USERIMAGES_SPARSE_EXT_FLAG),$(hide) echo "extfs_sparse_flag=$(INTERNAL_USERIMAGES_SPARSE_EXT_FLAG)" >> $(1))
$(if $(mkyaffs2_extra_flags),$(hide) echo "mkyaffs2_extra_flags=$(mkyaffs2_extra_flags)" >> $(1))
$(if $(2),$(hide) $(foreach kv,$(2),echo "$(kv)" >> $(1);))
endef


ifneq ($(BOARD_NAND_PAGE_SIZE),)
mkyaffs2_extra_flags := -c $(BOARD_NAND_PAGE_SIZE)
else
mkyaffs2_extra_flags :=
BOARD_NAND_PAGE_SIZE := 2048
endif

ifneq ($(BOARD_NAND_SPARE_SIZE),)
mkyaffs2_extra_flags += -s $(BOARD_NAND_SPARE_SIZE)
else
BOARD_NAND_SPARE_SIZE := 64
endif

# -----------------------------------------------------------------
# system image
#

INTERNAL_SYSTEMIMAGE_FILES := $(filter $(TARGET_OUT)/%, \
    $(ALL_PREBUILT) \
    $(ALL_COPIED_HEADERS) \
    $(ALL_GENERATED_SOURCES) \
    $(ALL_DEFAULT_INSTALLED_MODULES))


FULL_SYSTEMIMAGE_DEPS := $(INTERNAL_SYSTEMIMAGE_FILES) $(INTERNAL_USERIMAGES_DEPS)
# -----------------------------------------------------------------
# installed file list
# Depending on anything that $(BUILT_SYSTEMIMAGE) depends on.
# We put installed-files.txt ahead of image itself in the dependency graph
# so that we can get the size stat even if the build fails due to too large
# system image.
INSTALLED_FILES_FILE := $(PRODUCT_OUT)/installed-files.txt
$(INSTALLED_FILES_FILE): $(FULL_SYSTEMIMAGE_DEPS)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) build/tools/fileslist.py $(TARGET_OUT) > $@

systemimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE := $(systemimage_intermediates)/system.img

# $(1): output file
define build-systemimage-target
  @echo "Target system fs image: $(1)"
  @mkdir -p $(dir $(1)) $(systemimage_intermediates) && rm -rf $(systemimage_intermediates)/system_image_info.txt
  $(call generate-userimage-prop-dictionary, $(systemimage_intermediates)/system_image_info.txt, skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      ./build/tools/releasetools/build_image.py \
      $(TARGET_OUT) $(systemimage_intermediates)/system_image_info.txt $(1)
endef

$(BUILT_SYSTEMIMAGE): $(FULL_SYSTEMIMAGE_DEPS) $(INSTALLED_FILES_FILE)
	$(call build-systemimage-target,$@)

INSTALLED_SYSTEMIMAGE := $(PRODUCT_OUT)/system.img
SYSTEMIMAGE_SOURCE_DIR := $(TARGET_OUT)

$(INSTALLED_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE) $(RECOVERY_FROM_BOOT_PATCH) | $(ACP)
	@echo "Install system fs image: $@"
	$(copy-file-to-target)
	$(hide) $(call assert-max-image-size,$@ $(RECOVERY_FROM_BOOT_PATCH),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE),yaffs)

systemimage: $(INSTALLED_SYSTEMIMAGE)


# -----------------------------------------------------------------
# data partition image
INTERNAL_USERDATAIMAGE_FILES := \
    $(filter $(TARGET_OUT_DATA)/%,$(ALL_DEFAULT_INSTALLED_MODULES))

# Don't build userdata.img if it's extfs but no partition size
skip_userdata.img :=
ifdef INTERNAL_USERIMAGES_EXT_VARIANT
ifndef BOARD_USERDATAIMAGE_PARTITION_SIZE
skip_userdata.img := true
endif
endif

ifneq ($(skip_userdata.img),true)
userdataimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,userdata)
BUILT_USERDATAIMAGE_TARGET := $(PRODUCT_OUT)/userdata.img

define build-userdataimage-target
  $(call pretty,"Target userdata fs image: $(INSTALLED_USERDATAIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_DATA)
  @mkdir -p $(userdataimage_intermediates) && rm -rf $(userdataimage_intermediates)/userdata_image_info.txt
  $(call generate-userimage-prop-dictionary, $(userdataimage_intermediates)/userdata_image_info.txt, skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      ./build/tools/releasetools/build_image.py \
      $(TARGET_OUT_DATA) $(userdataimage_intermediates)/userdata_image_info.txt $(INSTALLED_USERDATAIMAGE_TARGET)
  $(hide) $(call assert-max-image-size,$(INSTALLED_USERDATAIMAGE_TARGET),$(BOARD_USERDATAIMAGE_PARTITION_SIZE),yaffs)
endef

# We just build this directly to the install location.
INSTALLED_USERDATAIMAGE_TARGET := $(BUILT_USERDATAIMAGE_TARGET)
$(INSTALLED_USERDATAIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) \
                                   $(INTERNAL_USERDATAIMAGE_FILES)
	$(build-userdataimage-target)
endif

