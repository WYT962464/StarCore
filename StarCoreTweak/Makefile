/**
 * Makefile
 * Theos编译配置
 * 
 * 适配多巴胺无根越狱(rootless)环境
 * 
 * 关键配置：
 * - THEOS_PACKAGE_SCHEME=rootless: 生成无根越狱格式的deb
 * - 安装目标: /var/jb/ (而非/)
 */

THEOS_DEVICE_ADDRESS := localhost
THEOS_DEVICE_PORT := 22

# 无根越狱配置（多巴胺Dopamine）
THEOS_PACKAGE_SCHEME := rootless

ARCHS := arm64 arm64e
TARGET := iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := StarCoreTweak

StarCoreTweak_FILES := Tweak.xm
StarCoreTweak_CFLAGS := -fobjc-arc

# 链接私有框架
StarCoreTweak_LDFLAGS += -framework IOKit -framework CoreGraphics
StarCoreTweak_LDFLAGS += -F/System/Library/PrivateFrameworks -framework BackBoardServices
StarCoreTweak_LDFLAGS += -F/System/Library/PrivateFrameworks -framework SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

# 无根越狱打包钩子
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
    PACKAGE_BEFORE_INSTALL += 
endif

.PHONY: clean install debug
