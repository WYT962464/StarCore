TARGET = iphone:clang:15.0:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StarCoreTweak
StarCoreTweak_FILES = Sources/Tweak.x
StarCoreTweak_CFLAGS = -fobjc-arc
StarCoreTweak_LIBRARIES = ellekit

include $(THEOS_MAKE_PATH)/tweak.mk
