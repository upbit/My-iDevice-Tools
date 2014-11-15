TARGET := iphone:7.1
ARCHS := armv7 arm64

include theos/makefiles/common.mk

TOOL_NAME = bundle_ids wifi_passwords

bundle_ids_FILES = bundle_ids.mm
bundle_ids_LIBRARIES = applist

wifi_passwords_FRAMEWORKS = Security
wifi_passwords_FILES = wifi_passwords.mm


include $(THEOS_MAKE_PATH)/tool.mk

ldid::
	export CODESIGN_ALLOCATE=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/codesign_allocate
	ldid -Sent.xml obj/wifi_passwords
