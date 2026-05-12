THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64e
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StarCoreTweak
StarCoreTweak_FILES = Tweak.mm
StarCoreTweak_CFLAGS = -fobjc-arc -w
StarCoreTweak_FRAMEWORKS = CoreGraphics UIKit
StarCoreTweak_CODESIGN_FLAGS = -Sentitlements.plist

# Use CydiaSubstrate framework (ElleKit compat layer)
StarCoreTweak_FRAMEWORKS += CydiaSubstrate
StarCoreTweak_LDFLAGS = -F/var/jb/Library/Frameworks -Wl,-undefined,dynamic_lookup

include $(THEOS)/makefiles/tweak.mk
