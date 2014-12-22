TARGET := iphone:7.1
ARCHS := armv7 armv7s arm64

include theos/makefiles/common.mk

TOOL_NAME = bundle_ids wifi_passwords keychain_cat

bundle_ids_FILES = bundle_ids.mm
bundle_ids_LIBRARIES = applist

wifi_passwords_FILES = wifi_passwords.mm
wifi_passwords_FRAMEWORKS = Security

keychain_cat_FILES = keychain_cat.mm
keychain_cat_FRAMEWORKS = Security
keychain_cat_LIBRARIES = sqlite3

include $(THEOS_MAKE_PATH)/tool.mk

after-all::
	export CODESIGN_ALLOCATE=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/codesign_allocate
	ldid -Sent.xml obj/wifi_passwords
	ldid -Sent.xml obj/keychain_cat
