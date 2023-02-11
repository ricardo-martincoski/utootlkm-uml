BASE_DIR := $(shell readlink -f .)
SRC_BUILDROOT_DIR := $(BASE_DIR)/buildroot
SRC_CONFIGS_DIR := $(BASE_DIR)/configs
SRC_DRIVERS_DIR := $(BASE_DIR)/drivers
SRC_LINUX_DIR := $(BASE_DIR)/linux
OUTPUT_DIR := $(BASE_DIR)/output
BUILD_BASE_DIR := $(OUTPUT_DIR)/build
BUILD_IMAGES_DIR := $(OUTPUT_DIR)/images
BUILD_TESTS_DIR := $(OUTPUT_DIR)/tests
BUILD_DRIVERS_DIR := $(BUILD_BASE_DIR)/drivers
BUILD_LINUX_DIR := $(BUILD_BASE_DIR)/linux
BUILD_MODULES_DIR := $(BUILD_BASE_DIR)/modules
BUILD_ROOTFS_FINAL_DIR := $(BUILD_BASE_DIR)/rootfs_final
BUILD_ROOTFS_INITIAL_DIR := $(BUILD_BASE_DIR)/rootfs_initial
CACHE_DOWNLOAD_DIR := $(BASE_DIR)/download
DOCKER_IMAGE := ricardomartincoski_opensource/utootlkm-uml/utootlkm-uml

check_inside_docker := $(shell if [ "`groups`" = 'br-user' ]; then echo y; else echo n; fi)
date := $(shell date +%Y%m%d.%H%M --utc)

real_targets_outside_docker := \
	.stamp_all \
	.stamp_submodules \

real_targets_inside_docker := \
	.stamp_linux \
	.stamp_modules_intree \
	.stamp_modules_out_of_tree \
	.stamp_modules_prepare \
	.stamp_rootfs_edit \
	.stamp_rootfs_final_generate \
	.stamp_rootfs_initial_extract \
	.stamp_rootfs_initial_generate \

phony_targets_outside_docker := \
	all \
	clean \
	clean-stamps \
	distclean \
	help \
	retest \
	submodules \

phony_targets_inside_docker := \
	linux \
	modules_intree \
	modules_out_of_tree \
	modules_prepare \
	rootfs_edit \
	rootfs_final \
	rootfs_initial \
	test \
	tests \

.PHONY: default $(phony_targets_inside_docker) $(phony_targets_outside_docker)
default: .stamp_all

ifeq ($(check_inside_docker),n) ########################################

$(real_targets_inside_docker) $(phony_targets_inside_docker): .stamp_submodules
	@echo "====== $@ ======"
	@utils/docker-run $(MAKE) $@

else # ($(check_inside_docker),n) ########################################

linux: .stamp_linux
	@echo "=== $@ ==="
.stamp_linux: .stamp_submodules
	@echo "=== $@ ==="
	@rm -rf $(BUILD_LINUX_DIR)
	@$(MAKE) ARCH=um O=$(BUILD_LINUX_DIR) -C $(SRC_LINUX_DIR) defconfig
	@install -D $(SRC_CONFIGS_DIR)/linux.defconfig $(BUILD_LINUX_DIR)/.config
	@$(MAKE) ARCH=um -C $(BUILD_LINUX_DIR) olddefconfig
	@$(MAKE) ARCH=um -C $(BUILD_LINUX_DIR)
	@install -D $(BUILD_LINUX_DIR)/vmlinux $(BUILD_IMAGES_DIR)/vmlinux
	@touch $@

modules_intree: .stamp_modules_intree
	@echo "=== $@ ==="
.stamp_modules_intree: .stamp_linux .stamp_rootfs_initial_extract
	@echo "=== $@ ==="
	@$(MAKE) ARCH=um -C $(BUILD_LINUX_DIR) modules_install INSTALL_MOD_PATH=$(BUILD_ROOTFS_FINAL_DIR)
	@touch $@

modules_prepare: .stamp_modules_prepare
	@echo "=== $@ ==="
.stamp_modules_prepare:
	@echo "=== $@ ==="
	@$(MAKE) ARCH=um O=$(BUILD_MODULES_DIR) -C $(SRC_LINUX_DIR) defconfig
	@install -D $(SRC_CONFIGS_DIR)/linux.defconfig $(BUILD_MODULES_DIR)/.config
	@$(MAKE) ARCH=um -C $(BUILD_MODULES_DIR) olddefconfig
	@$(MAKE) ARCH=um -C $(BUILD_MODULES_DIR) modules_prepare
	@touch $@

modules_out_of_tree: .stamp_modules_out_of_tree
	@echo "=== $@ ==="
.stamp_modules_out_of_tree: .stamp_modules_prepare
	@echo "=== $@ ==="
	@rm -rf $(BUILD_DRIVERS_DIR)
	@mkdir -p $(BUILD_DRIVERS_DIR)
	@$(foreach driver, $(wildcard $(SRC_DRIVERS_DIR)/*), \
		echo "--- $@ $(notdir $(driver)) ---" \
			&& rsync -vau $(driver)/ $(BUILD_DRIVERS_DIR)/$(notdir $(driver))/ \
			&& $(MAKE) ARCH=um -C $(BUILD_MODULES_DIR) M=$(BUILD_DRIVERS_DIR)/$(notdir $(driver))/ \
			&& $(MAKE) ARCH=um -C $(BUILD_MODULES_DIR) M=$(BUILD_DRIVERS_DIR)/$(notdir $(driver))/ modules_install INSTALL_MOD_PATH=$(BUILD_ROOTFS_FINAL_DIR) \
			; \
		)
	@touch $@

rootfs_initial: .stamp_rootfs_initial_generate
	@echo "=== $@ ==="
.stamp_rootfs_initial_generate: .stamp_submodules
	@echo "=== $@ ==="
	@rm -rf $(BUILD_ROOTFS_INITIAL_DIR)
	@$(MAKE) O=$(BUILD_ROOTFS_INITIAL_DIR) -C $(SRC_BUILDROOT_DIR) defconfig
	@install -D $(SRC_CONFIGS_DIR)/rootfs_defconfig $(BUILD_ROOTFS_INITIAL_DIR)/.config
	@$(MAKE) -C $(BUILD_ROOTFS_INITIAL_DIR) olddefconfig
	@$(MAKE) -C $(BUILD_ROOTFS_INITIAL_DIR) source
	@$(MAKE) -C $(BUILD_ROOTFS_INITIAL_DIR)
	@install -D $(BUILD_ROOTFS_INITIAL_DIR)/images/rootfs.cpio $(BUILD_IMAGES_DIR)/rootfs_initial.cpio
	@touch $@

.stamp_rootfs_initial_extract: .stamp_rootfs_initial_generate
	@echo "=== $@ ==="
	@rm -rf $(BUILD_ROOTFS_FINAL_DIR)
	@mkdir -p $(BUILD_ROOTFS_FINAL_DIR)
	@fakeroot -- cpio --extract --directory=$(BUILD_ROOTFS_FINAL_DIR) --make-directories --file=$(BUILD_IMAGES_DIR)/rootfs_initial.cpio
	@sed '/mknod.*console/d' -i $(BUILD_ROOTFS_FINAL_DIR)/init
	@sed '/#!\/bin\/sh/amknod /dev/console c 5 1' -i $(BUILD_ROOTFS_FINAL_DIR)/init
	@rm -f $(BUILD_ROOTFS_FINAL_DIR)/dev/console
	@touch $@

rootfs_edit: .stamp_rootfs_edit
	@echo "=== $@ ==="
.stamp_rootfs_edit: .stamp_modules_intree .stamp_modules_out_of_tree
	@echo "=== $@ ==="
	@touch $@

rootfs_final: .stamp_rootfs_final_generate
	@echo "=== $@ ==="
.stamp_rootfs_final_generate: .stamp_rootfs_edit
	@echo "=== $@ ==="
	@fakeroot bash -c 'cd $(BUILD_ROOTFS_FINAL_DIR) && find . | cpio --create --format=newc' > $(BUILD_IMAGES_DIR)/rootfs_final.cpio
	@touch $@

tests: .stamp_linux .stamp_rootfs_final_generate
	@echo "=== $@ ==="
	@rm -rf $(BUILD_TESTS_DIR)
	@mkdir -p $(BUILD_TESTS_DIR)
	@$(BASE_DIR)/tests/test.py

test: .stamp_linux .stamp_rootfs_final_generate
	@echo "=== $@ ==="
	@TMPDIR=$(shell mktemp -d) $(BUILD_IMAGES_DIR)/vmlinux mem=32M initrd=$(BUILD_IMAGES_DIR)/rootfs_final.cpio noreboot

endif # ($(check_inside_docker),n) ########################################

retest:
	@echo "=== $@ ==="
	@rm -f .stamp_modules_out_of_tree .stamp_rootfs_edit .stamp_rootfs_final_generate
	@$(MAKE) tests

all: .stamp_all
	@echo "=== $@ ==="
.stamp_all: tests
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
	@rm -rf $(SRC_BUILDROOT_DIR)
	@rm -rf $(SRC_LINUX_DIR)
	@rm -rf $(CACHE_DOWNLOAD_DIR)

docker-image:
	@echo "=== $@ ==="
	@docker build -t registry.gitlab.com/$(DOCKER_IMAGE):$(date) support/docker
	@sed -e 's,^image:.*,image: $$CI_REGISTRY/$(DOCKER_IMAGE):$(date),g' -i .gitlab-ci.yml
	@echo And now do:
	@echo docker push registry.gitlab.com/$(DOCKER_IMAGE):$(date)

help:
	@echo "**utootlkm-uml** stands for *Unit Tests for Out-Of-Tree Linux Kernel Modules,"
	@echo "User-Mode Linux variant*."
	@echo
	@echo "This project can be used as an infrastructure to run unit tests for any open"
	@echo "source Linux kernel module that is maintained in its own repository (out of the"
	@echo "main Linux git tree)."
	@echo
	@echo "Usage:"
	@echo "  make test - start the VM used to run unit tests (for manual testing)"
	@echo "  make - build UML and drivers and run unit tests"
	@echo "  make tests - run unit tests"
	@echo "  make retest - recompile only the drivers and run unit tests"
	@echo "  make clean"
	@echo "  make distclean - 'clean' + force submodule to be cloned"
	@echo "  make docker-image - generate a new docker image to be uploaded"
