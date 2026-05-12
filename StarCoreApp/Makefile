TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = StarCoreApp

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = StarCoreApp

StarCoreApp_FILES = \
	AppDelegate.swift \
	Models.swift \
	MemoryManager.swift \
	StarCoreAgent.swift \
	ChatViewController.swift \
	SettingsViewController.swift

StarCoreApp_FRAMEWORKS = UIKit Foundation Network
StarCoreApp_CFLAGS = -fobjc-arc
StarCoreApp_BUNDLE_NAME = StarCoreApp
StarCoreApp_INSTALL_PATH = /Applications

include $(THEOS)/makefiles/application.mk
