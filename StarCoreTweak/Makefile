# StarCoreTweak Makefile v3.0
# 适配多巴胺无根越狱(rootless)环境
# 注入目标：backboardd

THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = backboardd

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StarCoreTweak
StarCoreTweak_FILES = Tweak.xm
StarCoreTweak_CFLAGS = -fobjc-arc -w
StarCoreTweak_FRAMEWORKS = CoreGraphics

include $(THEOS)/makefiles/tweak.mk
