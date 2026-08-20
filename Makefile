export ARCHS = arm64
export TARGET = iphone:clang:16.0:13.0

include $(THEOS)/makefiles/common.mk

ADDITIONAL_CFLAGS = -fobjc-arc

TWEAK_NAME = YueyuKeyboard
YueyuKeyboard_FILES = Tweak.x YueyuTranslator.m YueyuSettings.m
YueyuKeyboard_CFLAGS = -fobjc-arc

BUNDLE_NAME = YueyuKeyboardSettings
YueyuKeyboardSettings_FILES = YueyuKeyboardSettings.m
YueyuKeyboardSettings_INSTALL_PATH = /Library/PreferenceBundles
YueyuKeyboardSettings_FRAMEWORKS = UIKit
YueyuKeyboardSettings_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk