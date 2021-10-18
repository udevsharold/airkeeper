TARGET := iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = akpd

akpd_FILES = $(wildcard *.m) $(wildcard *.mm) ../AKPNEUtilities.m ../AKPUtilities.mm
akpd_CFLAGS = -fobjc-arc -DAKPD=1
akpd_CODESIGN_FLAGS = -Sentitlements.plist
akpd_INSTALL_PATH = /usr/libexec
akpd_FRAMEWORKS = NetworkExtension

include $(THEOS_MAKE_PATH)/tool.mk
