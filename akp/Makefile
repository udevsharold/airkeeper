TARGET := iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = akp

akp_FILES = main.m ../AKPUtilities.mm ../AKPNetworkConfigurationUtilities.mm ../AKPPerAppVPNConfiguration.m
akp_CFLAGS = -fobjc-arc
akp_CODESIGN_FLAGS = -Sentitlements.plist
akp_INSTALL_PATH = /usr/local/bin
akp_PRIVATE_FRAMEWORKS = CoreTelephony MobileCoreServices
akp_FRAMEWORKS = NetworkExtension Security
akp_EXTRA_FRAMEWORKS = AltList

include $(THEOS_MAKE_PATH)/tool.mk
