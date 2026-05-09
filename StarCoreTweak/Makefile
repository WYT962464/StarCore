THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StarCoreTweak
StarCoreTweak_FILES = Tweak.xm
StarCoreTweak_CFLAGS = -fobjc-arc -w
StarCoreTweak_FRAMEWORKS = CoreGraphics UIKit

include $(THEOS)/makefiles/tweak.mk
