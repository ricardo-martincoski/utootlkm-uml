BASE_DIR := $(shell readlink -f .)
BUILDROOT_DIR := $(BASE_DIR)/buildroot
LINUX_DIR := $(BASE_DIR)/linux

real_targets := \
	.stamp_all \
	.stamp_submodules \

phony_targets := \
	all \
	clean \
	clean-stamps \
	distclean \
	help \
	submodules \

.PHONY: default $(phony_targets)
default: .stamp_all

all: .stamp_all
	@echo "=== $@ ==="
.stamp_all: .stamp_submodules
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

distclean: clean
	@echo "=== $@ ==="
	@rm -rf $(BUILDROOT_DIR)
	@rm -rf $(LINUX_DIR)

help:
	@echo "Usage:"
	@echo "  make"
	@echo "  make clean"
	@echo "  make distclean - 'clean' + force submodule to be cloned"
