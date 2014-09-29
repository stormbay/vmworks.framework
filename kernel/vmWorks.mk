LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

KERNEL_PATH  := $(LOCAL_PATH)
KERNEL_IMAGE := $(LOCAL_PATH)/arch/arm/boot/uImage


LOCAL_MODULE := kernel
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := PREBUILT
LOCAL_MODULE_PATH := $(PRODUCT_OUT)
LOCAL_SRC_FILES := $(KERNEL_IMAGE)
include $(BUILD_PREBUILT)


$(KERNEL_IMAGE)::
	make -C $(KERNEL_PATH) $(TARGET_KERNEL_CONFIG)
	make -C $(KERNEL_PATH) uImage

KERNEL_INTERMEDIATES := $(local-intermediates-dir)/kernel
$(KERNEL_INTERMEDIATES): $(KERNEL_IMAGE)
	$(copy-file-to-target-with-cp)

.PHONY: KERNEL_OBJ
KERNEL_OBJ: $(KERNEL_INTERMEDIATES)
