PDW_ZMQ_VERSION = 1.0.0
PDW_ZMQ_SITE = $(realpath $(BR2_EXTERNAL_PLUTOSDR_PATH)/../pdw-zmq)
PDW_ZMQ_SITE_METHOD = local
PDW_ZMQ_DEPENDENCIES = zeromq

define PDW_ZMQ_BUILD_CMDS
	# Build pdw-publisher daemon
	$(TARGET_CC) $(TARGET_CFLAGS) \
		-I$(STAGING_DIR)/usr/include \
		-o $(@D)/daemon/pdw-publisher \
		$(@D)/daemon/pdw_publisher.c \
		-L$(STAGING_DIR)/usr/lib -lzmq -lstdc++ -lpthread
	# Build helper binaries (static, no libzmq dependency)
	$(TARGET_CC) $(TARGET_CFLAGS) -static \
		-o $(@D)/helpers/uio_reg $(@D)/helpers/uio_reg.c
	$(TARGET_CC) $(TARGET_CFLAGS) -static \
		-o $(@D)/helpers/dma_read $(@D)/helpers/dma_read.c
endef

define PDW_ZMQ_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/daemon/pdw-publisher \
		$(TARGET_DIR)/usr/bin/pdw-publisher
	$(INSTALL) -D -m 0755 $(@D)/helpers/uio_reg \
		$(TARGET_DIR)/usr/bin/uio_reg
	$(INSTALL) -D -m 0755 $(@D)/helpers/dma_read \
		$(TARGET_DIR)/usr/bin/dma_read
endef

$(eval $(generic-package))
