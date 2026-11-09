# 使用 iPhoneOS9.3 SDK（与设备 iOS 9 一致；需补一个缺失的 liblaunch.tbd 存根），部署目标 iOS 9.0
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
