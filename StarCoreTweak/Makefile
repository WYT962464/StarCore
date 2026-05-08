# StarCoreTweak Makefile
# 适配多巴胺无根越狱(rootless)环境

THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StarCoreTweak
StarCoreTweak_FILES = Tweak.xm
StarCoreTweak_CFLAGS = -fobjc-arc -w

include $(THEOS)/makefiles/tweak.mk
