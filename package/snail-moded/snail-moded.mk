################################################################################
#
# snail-moded — DiSCO-SNAIL mode manager REST daemon
#
################################################################################

SNAIL_MODED_VERSION = 0.1.0
SNAIL_MODED_SITE = $(realpath $(BR2_EXTERNAL_PLUTOSDR_PATH)/../snail-moded)
SNAIL_MODED_SITE_METHOD = local

CROSS_COMPILE = arm-none-linux-gnueabihf-
SNAIL_MODED_TOOLCHAIN = "$(HOST_DIR)/bin/$(CROSS_COMPILE)gcc"

define SNAIL_MODED_BUILD_CMDS
$(shell bash -c "PATH=\"$(HOST_DIR)/bin:$(PATH)\" && cd $(SNAIL_MODED_SRCDIR) && \
  cargo build --release --target armv7-unknown-linux-gnueabihf \
  --config target.armv7-unknown-linux-gnueabihf.linker='\"'$(SNAIL_MODED_TOOLCHAIN)'\"' ")
endef

define SNAIL_MODED_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 \
            $(SNAIL_MODED_SRCDIR)/target/armv7-unknown-linux-gnueabihf/release/snail-moded \
            $(TARGET_DIR)/usr/bin/snail-moded
endef

$(eval $(generic-package))
