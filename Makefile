export ARCHS = arm64
export TARGET = iphone:clang:16.0:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YueyuKeyboard
YueyuKeyboard_FILES = Tweak.x
YueyuKeyboard_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk