# ???? iOS 9.3 SDK(?? armv7),???? iOS 9.0
export TARGET := iphone:clang:9.3:9.0
export ARCHS := armv7
export DEBUG := 0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IPAInstaller

IPAInstaller_FILES = IPAInstaller.mm
IPAInstaller_INSTALL_PATH = /Applications
IPAInstaller_ENTITLEMENTS = entitlements.plist
IPAInstaller_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/application.mk
