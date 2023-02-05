BASE_DIR := $(shell readlink -f .)
BUILDROOT_DIR := $(BASE_DIR)/buildroot
LINUX_DIR := $(BASE_DIR)/linux
DRIVERS_DIR := $(BASE_DIR)/drivers
DOWNLOAD_DIR := $(BASE_DIR)/download
OUTPUT_DIR := $(BASE_DIR)/output
BUILD_DIR := $(OUTPUT_DIR)/build
IMAGES_DIR := $(OUTPUT_DIR)/images

real_targets := \
	.stamp_all \
	.stamp_linux \
	.stamp_modules_intree \
	.stamp_modules_out_of_tree \
	.stamp_modules_prepare \
	.stamp_rootfs_edit \
	.stamp_rootfs_extract \
	.stamp_rootfs_final \
	.stamp_rootfs_initial \
	.stamp_submodules \

phony_targets := \
	all \
	clean \
	clean-stamps \
	distclean \
	help \
	linux \
	modules_intree \
	modules_out_of_tree \
	modules_prepare \
	rootfs_edit \
	rootfs_extract \
	rootfs_final \
	rootfs_initial \
	submodules \
	test \

.PHONY: default $(phony_targets)
default: .stamp_all

linux: .stamp_linux
	@echo "=== $@ ==="
.stamp_linux: .stamp_submodules
	@echo "=== $@ ==="
	@rm -rf $(BUILD_DIR)/linux
	@$(MAKE) ARCH=um O=$(BUILD_DIR)/linux -C $(LINUX_DIR) defconfig
	@install -D $(BASE_DIR)/configs/linux.defconfig $(BUILD_DIR)/linux/.config
	@$(MAKE) ARCH=um -C $(BUILD_DIR)/linux olddefconfig
	@$(MAKE) ARCH=um -C $(BUILD_DIR)/linux
	@install -D $(BUILD_DIR)/linux/vmlinux $(IMAGES_DIR)/vmlinux
	@touch $@

modules_intree: .stamp_modules_intree
	@echo "=== $@ ==="
.stamp_modules_intree: .stamp_linux .stamp_rootfs_extract
	@echo "=== $@ ==="
	@$(MAKE) ARCH=um -C $(BUILD_DIR)/linux modules_install INSTALL_MOD_PATH=$(BUILD_DIR)/rootfs_final
	@touch $@

modules_prepare: .stamp_modules_prepare
	@echo "=== $@ ==="
.stamp_modules_prepare:
	@echo "=== $@ ==="
	@$(MAKE) ARCH=um O=$(BUILD_DIR)/modules -C $(LINUX_DIR) defconfig
	@install -D $(BASE_DIR)/configs/linux.defconfig $(BUILD_DIR)/modules/.config
	@$(MAKE) ARCH=um -C $(BUILD_DIR)/modules olddefconfig
	@$(MAKE) ARCH=um -C $(BUILD_DIR)/modules modules_prepare
	@touch $@

modules_out_of_tree: .stamp_modules_out_of_tree
	@echo "=== $@ ==="
.stamp_modules_out_of_tree: .stamp_modules_prepare
	@echo "=== $@ ==="
	@rm -rf $(BUILD_DIR)/drivers
	@mkdir -p $(BUILD_DIR)/drivers
	@$(foreach driver, $(wildcard $(DRIVERS_DIR)/*), \
		echo "--- $@ $(notdir $(driver)) ---" \
			&& rsync -vau $(driver)/ $(BUILD_DIR)/drivers/$(notdir $(driver))/ \
			&& $(MAKE) ARCH=um -C $(BUILD_DIR)/modules M=$(BUILD_DIR)/drivers/$(notdir $(driver))/ \
			&& $(MAKE) ARCH=um -C $(BUILD_DIR)/modules M=$(BUILD_DIR)/drivers/$(notdir $(driver))/ modules_install INSTALL_MOD_PATH=$(BUILD_DIR)/rootfs_final \
		)
	@touch $@

rootfs_initial: .stamp_rootfs_initial
	@echo "=== $@ ==="
.stamp_rootfs_initial: .stamp_submodules
	@echo "=== $@ ==="
	@rm -rf $(BUILD_DIR)/rootfs_initial
	@$(MAKE) O=$(BUILD_DIR)/rootfs_initial -C $(BUILDROOT_DIR) defconfig
	@install -D $(BASE_DIR)/configs/rootfs_defconfig $(BUILD_DIR)/rootfs_initial/.config
	@$(MAKE) -C $(BUILD_DIR)/rootfs_initial olddefconfig
	@$(MAKE) -C $(BUILD_DIR)/rootfs_initial
	@install -D $(BUILD_DIR)/rootfs_initial/images/rootfs.cpio $(IMAGES_DIR)/rootfs_initial.cpio
	@touch $@

rootfs_extract: .stamp_rootfs_extract
	@echo "=== $@ ==="
.stamp_rootfs_extract: .stamp_rootfs_initial
	@echo "=== $@ ==="
	@rm -rf $(BUILD_DIR)/rootfs_final
	@mkdir -p $(BUILD_DIR)/rootfs_final
	@fakeroot bash -c 'cpio --extract --directory=$(BUILD_DIR)/rootfs_final --make-directories < $(IMAGES_DIR)/rootfs_initial.cpio'
	@sed '/mknod.*console/d' -i $(BUILD_DIR)/rootfs_final/init
	@sed '/#!\/bin\/sh/amknod /dev/console c 5 1' -i $(BUILD_DIR)/rootfs_final/init
	@rm -f $(BUILD_DIR)/rootfs_final/dev/console
	@touch $@

rootfs_edit: .stamp_rootfs_edit
	@echo "=== $@ ==="
.stamp_rootfs_edit: .stamp_modules_intree .stamp_modules_out_of_tree
	@echo "=== $@ ==="
	@touch $@

rootfs_final: .stamp_rootfs_final
	@echo "=== $@ ==="
.stamp_rootfs_final: .stamp_rootfs_edit
	@echo "=== $@ ==="
	@fakeroot bash -c 'cd $(BUILD_DIR)/rootfs_final && find . | cpio --create --format=newc' > $(IMAGES_DIR)/rootfs_final.cpio
	@touch $@

test: .stamp_linux .stamp_rootfs_final
	@echo "=== $@ ==="
	@$(IMAGES_DIR)/vmlinux mem=32M initrd=$(IMAGES_DIR)/rootfs_final.cpio noreboot

all: .stamp_all
	@echo "=== $@ ==="
.stamp_all: test
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
	@rm -rf $(DOWNLOAD_DIR)
	@rm -rf $(LINUX_DIR)

help:
	@echo "Usage:"
	@echo "  make"
	@echo "  make clean"
	@echo "  make distclean - 'clean' + force submodule to be cloned"
