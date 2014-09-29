#
# A mapping from shorthand names to include directories.
#
pathmap_INCL := \
    libc:prebuilts/gcc/linux-x86/arm/arm-none-linux-gnueabi-4.3.3/arm-none-linux-gnueabi/libc/usr/include	\
    libm:prebuilts/gcc/linux-x86/arm/arm-none-linux-gnueabi-4.3.3/arm-none-linux-gnueabi/libc/usr/includes	\
    libstdc++:prebuilts/gcc/linux-x86/arm/arm-none-linux-gnueabi-4.3.3/arm-none-linux-gnueabi/include		\
    libhost:build/libs/host/include		\
	system-core:system/core/include

#
# Returns the path to the requested module's include directory,
# relative to the root of the source tree.  Does not handle external
# modules.
#
# $(1): a list of modules (or other named entities) to find the includes for
#
define include-path-for
$(foreach n,$(1),$(patsubst $(n):%,%,$(filter $(n):%,$(pathmap_INCL))))
endef

