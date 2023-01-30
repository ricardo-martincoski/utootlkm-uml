BASE_DIR := $(shell readlink -f .)
BUILDROOT_DIR := $(BASE_DIR)/buildroot
LINUX_DIR := $(BASE_DIR)/linux
OUTPUT_DIR := $(BASE_DIR)/output
BUILD_DIR := $(OUTPUT_DIR)/build
IMAGES_DIR := $(OUTPUT_DIR)/images

real_targets := \
	.stamp_all \
	.stamp_linux \
	.stamp_rootfs_initial \
	.stamp_rootfs_final \
	.stamp_submodules \

phony_targets := \
	all \
	clean \
	clean-stamps \
	distclean \
	help \
	linux \
	rootfs_initial \
	rootfs_final \
	submodules \

.PHONY: default $(phony_targets)
default: .stamp_all

linux: .stamp_linux
	@echo "=== $@ ==="
.stamp_linux: .stamp_submodules
	@echo "=== $@ ==="
	@$(MAKE) ARCH=um O=$(BUILD_DIR)/linux -C $(LINUX_DIR) defconfig
	@install -D $(BASE_DIR)/configs/linux.defconfig $(BUILD_DIR)/linux/.config
	@$(MAKE) ARCH=um -C $(BUILD_DIR)/linux olddefconfig
	@$(MAKE) ARCH=um -C $(BUILD_DIR)/linux
	@install -D $(BUILD_DIR)/linux/vmlinux $(IMAGES_DIR)/vmlinux
	@touch $@

rootfs_initial: .stamp_rootfs_initial
	@echo "=== $@ ==="
.stamp_rootfs_initial: .stamp_submodules
	@echo "=== $@ ==="
	@$(MAKE) O=$(BUILD_DIR)/rootfs_initial -C $(BUILDROOT_DIR) defconfig
	@install -D $(BASE_DIR)/configs/rootfs_defconfig $(BUILD_DIR)/rootfs_initial/.config
	@$(MAKE) -C $(BUILD_DIR)/rootfs_initial olddefconfig
	@$(MAKE) -C $(BUILD_DIR)/rootfs_initial
	@install -D $(BUILD_DIR)/rootfs_initial/images/rootfs.cpio $(IMAGES_DIR)/rootfs_initial.cpio
	@touch $@

rootfs_final: .stamp_rootfs_final
	@echo "=== $@ ==="
.stamp_rootfs_final: .stamp_linux .stamp_rootfs_initial
	@echo "=== $@ ==="
	@rm -rf $(BUILD_DIR)/rootfs_final
	@mkdir -p $(BUILD_DIR)/rootfs_final
	@fakeroot bash -c 'cpio --extract --directory=$(BUILD_DIR)/rootfs_final --make-directories < $(IMAGES_DIR)/rootfs_initial.cpio'
	@sed '/mknod.*console/d' -i $(BUILD_DIR)/rootfs_final/init
	@sed '/#!\/bin\/sh/amknod /dev/console c 5 1' -i $(BUILD_DIR)/rootfs_final/init
	@rm -f $(BUILD_DIR)/rootfs_final/dev/console
	@$(MAKE) ARCH=um -C $(BUILD_DIR)/linux modules_install INSTALL_MOD_PATH=$(BUILD_DIR)/rootfs_final
	@fakeroot bash -c 'cd $(BUILD_DIR)/rootfs_final && find . | cpio --create --format=newc' > $(IMAGES_DIR)/rootfs_final.cpio
	@touch $@

all: .stamp_all
	@echo "=== $@ ==="
.stamp_all: .stamp_linux .stamp_rootfs_final
	@echo "=== $@ ==="
	@touch $@

submodules: .stamp_submodules
	@echo "=== $@ ==="
.stamp_submodules:
	@echo "=== $@ ==="
	@git submodule init
	@git submodule update
	@touch $@

clean-stamps:
	@echo "=== $@ ==="
	@rm -rf .stamp_submodules
	@rm -rf .stamp_*

clean: clean-stamps
	@echo "=== $@ ==="
	@rm -rf $(OUTPUT_DIR)

distclean: clean
	@echo "=== $@ ==="
	@rm -rf $(BUILDROOT_DIR)
	@rm -rf $(LINUX_DIR)

help:
	@echo "Usage:"
	@echo "  make"
	@echo "  make clean"
	@echo "  make distclean - 'clean' + force submodule to be cloned"
