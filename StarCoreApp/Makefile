TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = StarCoreApp

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = StarCoreApp

StarCoreApp_FILES = \
	AppDelegate.swift \
	Models.swift \
	MemoryManager.swift \
	MemoryViewController.swift \
	StarCoreAgent.swift \
	ChatViewController.swift \
	SettingsViewController.swift \
	MarkdownRenderer.swift \
	StreamingLLM.swift \
	ImagePickerHelper.swift \
	XiaoZhiManager.swift


StarCoreApp_FRAMEWORKS = UIKit Foundation Network WebKit
StarCoreApp_CFLAGS = -fobjc-arc
StarCoreApp_BUNDLE_NAME = StarCoreApp
StarCoreApp_INSTALL_PATH = /Applications
StarCoreApp_INFO_PLIST = Info.plist

include $(THEOS)/makefiles/application.mk
