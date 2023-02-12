BASE_DIR := $(shell readlink -f .)
SRC_BUILDROOT_DIR := $(BASE_DIR)/buildroot
SRC_CONFIGS_DIR := $(BASE_DIR)/configs
SRC_DRIVERS_DIR := $(BASE_DIR)/drivers
OUTPUT_DIR := $(BASE_DIR)/output
BUILD_BASE_DIR := $(OUTPUT_DIR)/build
BUILD_IMAGES_DIR := $(OUTPUT_DIR)/images
BUILD_TESTS_DIR := $(OUTPUT_DIR)/tests
BUILD_DRIVERS_DIR := $(BUILD_BASE_DIR)/drivers
BUILD_LINUX_DIR := $(BUILD_BASE_DIR)/linux
BUILD_LINUX_DOWNLOAD_DIR := $(BUILD_BASE_DIR)/linux_download
BUILD_ROOTFS_FINAL_DIR := $(BUILD_BASE_DIR)/rootfs_final
BUILD_ROOTFS_INITIAL_DIR := $(BUILD_BASE_DIR)/rootfs_initial
BUILD_ROOTFS_PARTIAL_DIR := $(BUILD_BASE_DIR)/rootfs_partial
CACHE_DOWNLOAD_DIR := $(BASE_DIR)/download
CACHE_LINUX_SRC := $(CACHE_DOWNLOAD_DIR)/linux/linux-5.10.165.tar.xz
URL_DOCKER_IMAGE := ricardomartincoski_opensource/utootlkm-uml/utootlkm-uml
ARTIFACT_LINUX_BIN := $(BUILD_IMAGES_DIR)/vmlinux
ARTIFACT_LINUX_SRC_DIR := $(BUILD_IMAGES_DIR)/linux
ARTIFACT_MODULES_PREPARE := $(BUILD_IMAGES_DIR)/modules
ARTIFACT_ROOTFS_FINAL := $(BUILD_IMAGES_DIR)/rootfs_final.cpio
ARTIFACT_ROOTFS_INITIAL := $(BUILD_IMAGES_DIR)/rootfs_initial.cpio
ARTIFACT_ROOTFS_PARTIAL := $(BUILD_IMAGES_DIR)/rootfs_partial.cpio
ARTIFACT_SDK := $(BASE_DIR)/sdk-utootlkm-uml.tar.xz

# make V=1 will enable verbose mode
V ?= 0
ifeq ($(V),0)
Q := @
else
Q :=
endif

# used with foreach and multiple commands
define newline


endef

check_inside_docker := $(shell if [ "`groups`" = 'br-user' ]; then echo y; else echo n; fi)
date := $(shell date +%Y%m%d.%H%M --utc)

real_targets_outside_docker := \
	.stamp_all \
	.stamp_submodules \

real_targets_inside_docker := \
	.stamp_linux \
	.stamp_linux_extract \
	.stamp_modules_intree \
	.stamp_modules_out_of_tree \
	.stamp_modules_prepare \
	.stamp_rootfs_final_generate \
	.stamp_rootfs_initial_extract \
	.stamp_rootfs_initial_generate \
	.stamp_rootfs_partial_extract \
	.stamp_rootfs_partial_generate \

targets_to_rebuild_on_rerun := \
	.stamp_modules_out_of_tree \
	.stamp_rootfs_final_generate \
	.stamp_rootfs_partial_extract \

phony_targets_outside_docker := \
	all \
	clean \
	clean-stamps \
	distclean \
	help \
	rerun-all-tests \
	sdk-extract \
	sdk-generate \
	submodules \

phony_targets_inside_docker := \
	linux \
	linux-extract \
	modules-intree \
	modules-out-of-tree \
	modules-prepare \
	rootfs-final \
	rootfs-initial \
	rootfs-partial \
	run-all-tests \
	start-vm \

.PHONY: default $(phony_targets_inside_docker) $(phony_targets_outside_docker)
default: .stamp_all

ifeq ($(check_inside_docker),n) ########################################

$(real_targets_inside_docker) $(phony_targets_inside_docker): .stamp_submodules
	$(Q)echo "====== $@ ======"
	$(Q)utils/docker-run $(MAKE) V=$(V) $@

else # ($(check_inside_docker),n) ########################################

linux-extract: .stamp_linux_extract
	$(Q)echo "=== $@ ==="
.stamp_linux_extract: .stamp_submodules
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(BUILD_LINUX_DOWNLOAD_DIR)
	$(Q)$(MAKE) O=$(BUILD_LINUX_DOWNLOAD_DIR) -C $(SRC_BUILDROOT_DIR) defconfig
	$(Q)install -D $(SRC_CONFIGS_DIR)/linux_download_defconfig $(BUILD_LINUX_DOWNLOAD_DIR)/.config
	$(Q)$(MAKE) -C $(BUILD_LINUX_DOWNLOAD_DIR) olddefconfig
	$(Q)$(MAKE) -C $(BUILD_LINUX_DOWNLOAD_DIR) linux-source
	$(Q)rm -rf $(ARTIFACT_LINUX_SRC_DIR)
	$(Q)mkdir -p $(ARTIFACT_LINUX_SRC_DIR)
	$(Q)tar --extract --strip-components=1 --directory=$(ARTIFACT_LINUX_SRC_DIR) --file=$(CACHE_LINUX_SRC)
	$(Q)touch $@

linux: .stamp_linux
	$(Q)echo "=== $@ ==="
.stamp_linux: .stamp_linux_extract
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(BUILD_LINUX_DIR)
	$(Q)$(MAKE) ARCH=um O=$(BUILD_LINUX_DIR) -C $(ARTIFACT_LINUX_SRC_DIR) defconfig
	$(Q)install -D $(SRC_CONFIGS_DIR)/linux.defconfig $(BUILD_LINUX_DIR)/.config
	$(Q)$(MAKE) ARCH=um -C $(BUILD_LINUX_DIR) olddefconfig
	$(Q)$(MAKE) ARCH=um -C $(BUILD_LINUX_DIR)
	$(Q)install -D $(BUILD_LINUX_DIR)/vmlinux $(ARTIFACT_LINUX_BIN)
	$(Q)touch $@

modules-intree: .stamp_modules_intree
	$(Q)echo "=== $@ ==="
.stamp_modules_intree: .stamp_linux .stamp_rootfs_initial_extract
	$(Q)echo "=== $@ ==="
	$(Q)$(MAKE) ARCH=um -C $(BUILD_LINUX_DIR) modules_install INSTALL_MOD_PATH=$(BUILD_ROOTFS_PARTIAL_DIR)
	$(Q)touch $@

modules-prepare: .stamp_modules_prepare
	$(Q)echo "=== $@ ==="
.stamp_modules_prepare: .stamp_linux_extract
	$(Q)echo "=== $@ ==="
	$(Q)$(MAKE) ARCH=um O=$(ARTIFACT_MODULES_PREPARE) -C $(ARTIFACT_LINUX_SRC_DIR) defconfig
	$(Q)install -D $(SRC_CONFIGS_DIR)/linux.defconfig $(ARTIFACT_MODULES_PREPARE)/.config
	$(Q)$(MAKE) ARCH=um -C $(ARTIFACT_MODULES_PREPARE) olddefconfig
	$(Q)$(MAKE) ARCH=um -C $(ARTIFACT_MODULES_PREPARE) modules_prepare
	$(Q)touch $@

modules-out-of-tree: .stamp_modules_out_of_tree
	$(Q)echo "=== $@ ==="
.stamp_modules_out_of_tree: .stamp_modules_prepare .stamp_rootfs_partial_extract
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(BUILD_DRIVERS_DIR)
	$(Q)mkdir -p $(BUILD_DRIVERS_DIR)
	$(Q)$(foreach driver, $(wildcard $(SRC_DRIVERS_DIR)/*),\
		echo "--- $@ $(notdir $(driver)) ---" $(newline)\
		rsync -vau $(driver)/ $(BUILD_DRIVERS_DIR)/$(notdir $(driver))/ $(newline) \
		$(MAKE) ARCH=um -C $(ARTIFACT_MODULES_PREPARE) M=$(BUILD_DRIVERS_DIR)/$(notdir $(driver))/ $(newline) \
		$(MAKE) ARCH=um -C $(ARTIFACT_MODULES_PREPARE) M=$(BUILD_DRIVERS_DIR)/$(notdir $(driver))/ modules_install INSTALL_MOD_PATH=$(BUILD_ROOTFS_FINAL_DIR) $(newline) \
		)
	$(Q)touch $@

rootfs-initial: .stamp_rootfs_initial_generate
	$(Q)echo "=== $@ ==="
.stamp_rootfs_initial_generate: .stamp_submodules
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(BUILD_ROOTFS_INITIAL_DIR)
	$(Q)$(MAKE) O=$(BUILD_ROOTFS_INITIAL_DIR) -C $(SRC_BUILDROOT_DIR) defconfig
	$(Q)install -D $(SRC_CONFIGS_DIR)/rootfs_defconfig $(BUILD_ROOTFS_INITIAL_DIR)/.config
	$(Q)$(MAKE) -C $(BUILD_ROOTFS_INITIAL_DIR) olddefconfig
	$(Q)$(MAKE) -C $(BUILD_ROOTFS_INITIAL_DIR) source
	$(Q)$(MAKE) -C $(BUILD_ROOTFS_INITIAL_DIR)
	$(Q)install -D $(BUILD_ROOTFS_INITIAL_DIR)/images/rootfs.cpio $(ARTIFACT_ROOTFS_INITIAL)
	$(Q)touch $@

.stamp_rootfs_initial_extract: .stamp_rootfs_initial_generate
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(BUILD_ROOTFS_PARTIAL_DIR)
	$(Q)mkdir -p $(BUILD_ROOTFS_PARTIAL_DIR)
	$(Q)fakeroot -- cpio --extract --directory=$(BUILD_ROOTFS_PARTIAL_DIR) --make-directories --file=$(ARTIFACT_ROOTFS_INITIAL)
	$(Q)sed '/mknod.*console/d' -i $(BUILD_ROOTFS_PARTIAL_DIR)/init
	$(Q)sed '/#!\/bin\/sh/amknod /dev/console c 5 1' -i $(BUILD_ROOTFS_PARTIAL_DIR)/init
	$(Q)rm -f $(BUILD_ROOTFS_PARTIAL_DIR)/dev/console
	$(Q)touch $@

rootfs-partial: .stamp_rootfs_partial_generate
	$(Q)echo "=== $@ ==="
.stamp_rootfs_partial_generate: .stamp_modules_intree
	$(Q)echo "=== $@ ==="
	$(Q)fakeroot bash -c 'cd $(BUILD_ROOTFS_PARTIAL_DIR) && find . | cpio --create --format=newc' > $(ARTIFACT_ROOTFS_PARTIAL)
	$(Q)touch $@

.stamp_rootfs_partial_extract: .stamp_rootfs_partial_generate
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(BUILD_ROOTFS_FINAL_DIR)
	$(Q)mkdir -p $(BUILD_ROOTFS_FINAL_DIR)
	$(Q)fakeroot -- cpio --extract --directory=$(BUILD_ROOTFS_FINAL_DIR) --make-directories --file=$(ARTIFACT_ROOTFS_PARTIAL)
	$(Q)touch $@

rootfs-final: .stamp_rootfs_final_generate
	$(Q)echo "=== $@ ==="
.stamp_rootfs_final_generate: .stamp_modules_out_of_tree
	$(Q)echo "=== $@ ==="
	$(Q)fakeroot bash -c 'cd $(BUILD_ROOTFS_FINAL_DIR) && find . | cpio --create --format=newc' > $(ARTIFACT_ROOTFS_FINAL)
	$(Q)touch $@

run-all-tests: .stamp_linux .stamp_rootfs_final_generate
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(BUILD_TESTS_DIR)
	$(Q)mkdir -p $(BUILD_TESTS_DIR)
	$(Q)$(BASE_DIR)/tests/test.py

start-vm: .stamp_linux .stamp_rootfs_final_generate
	$(Q)echo "=== $@ ==="
	$(Q)TMPDIR=$(shell mktemp -d) $(ARTIFACT_LINUX_BIN) mem=32M initrd=$(ARTIFACT_ROOTFS_FINAL) noreboot

endif # ($(check_inside_docker),n) ########################################

rerun-all-tests:
	$(Q)echo "=== $@ ==="
	$(Q)rm -f $(targets_to_rebuild_on_rerun)
	$(Q)$(MAKE) run-all-tests

sdk-generate: .stamp_linux .stamp_rootfs_partial_generate .stamp_modules_prepare
	$(Q)echo "=== $@ ==="
	$(Q)tar --verbose --create --xz --file=$(ARTIFACT_SDK) .stamp* \
		$(foreach f, \
			$(ARTIFACT_LINUX_BIN) \
			$(ARTIFACT_LINUX_SRC_DIR) \
			$(ARTIFACT_MODULES_PREPARE) \
			$(ARTIFACT_ROOTFS_PARTIAL) \
			, $(subst $(BASE_DIR)/,,$(f)))

sdk-extract: .stamp_submodules
	$(Q)echo "=== $@ ==="
	$(Q)tar --extract --file=$(ARTIFACT_SDK)
	$(Q)rm -f $(targets_to_rebuild_on_rerun)

all: .stamp_all
	$(Q)echo "=== $@ ==="
.stamp_all: run-all-tests
	$(Q)echo "=== $@ ==="
	$(Q)touch $@

submodules: .stamp_submodules
	$(Q)echo "=== $@ ==="
.stamp_submodules:
	$(Q)echo "=== $@ ==="
	$(Q)git submodule init
	$(Q)git submodule update
	$(Q)touch $@

clean-stamps:
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf .stamp_submodules
	$(Q)rm -rf .stamp_*

clean: clean-stamps
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(OUTPUT_DIR)

distclean: clean
	$(Q)echo "=== $@ ==="
	$(Q)rm -rf $(SRC_BUILDROOT_DIR)
	$(Q)rm -rf $(CACHE_DOWNLOAD_DIR)

docker-image:
	$(Q)echo "=== $@ ==="
	$(Q)docker build -t registry.gitlab.com/$(URL_DOCKER_IMAGE):$(date) support/docker
	$(Q)sed -e 's,^image:.*,image: $$CI_REGISTRY/$(URL_DOCKER_IMAGE):$(date),g' -i .gitlab-ci.yml
	$(Q)echo And now do:
	$(Q)echo docker push registry.gitlab.com/$(URL_DOCKER_IMAGE):$(date)

help:
	$(Q)echo "**utootlkm-uml** stands for *Unit Tests for Out-Of-Tree Linux Kernel Modules,"
	$(Q)echo "User-Mode Linux variant*."
	$(Q)echo
	$(Q)echo "This project can be used as an infrastructure to run unit tests for any open"
	$(Q)echo "source Linux kernel module that is maintained in its own repository (out of the"
	$(Q)echo "main Linux git tree)."
	$(Q)echo
	$(Q)echo "Usage:"
	$(Q)echo "  make start-vm - start the VM used to run unit tests (for manual testing)"
	$(Q)echo "  make - build UML and drivers and run unit tests"
	$(Q)echo "  make run-all-tests - run unit tests"
	$(Q)echo "  make rerun-all-tests - recompile only the drivers and run unit tests"
	$(Q)echo "  make clean"
	$(Q)echo "  make distclean - 'clean' + force submodule to be cloned"
	$(Q)echo "  make docker-image - generate a new docker image to be uploaded"
	$(Q)echo "  make V=1 <target> - calls the target enabling verbose output"
	$(Q)echo "  make sdk-generate - prebuild dependencies to test out-of-tree drivers"
	$(Q)echo "  make sdk-extract - extract prebuilt dependencies to test out-of-tree drivers"
	$(Q)echo ""
	$(Q)echo "Dependencies:"
	$(Q)echo " +------------------------------------------------+"
	$(Q)echo " |             rootfs-initial    modules-intree   |"
	$(Q)echo " |                         |      |          ^    |--> sdk-generate"
	$(Q)echo " |                         |      |          |    |"
	$(Q)echo " |                         v      v          |    |<-- sdk-extract"
	$(Q)echo " | modules-prepare        rootfs-partial    linux |"
	$(Q)echo " |  |                      |                 |    |"
	$(Q)echo " +--|----------------------|-----------------|----+"
	$(Q)echo "    v                      v                 v"
	$(Q)echo "   modules-out-of-tree -> rootfs-final ---> run-all-tests"
	$(Q)echo "   ^^                     ^^                ^^"
	$(Q)echo "   ||                     ||                ||"
	$(Q)echo "   ++=====================++================++== rerun-all-tests"
	$(Q)echo ""
