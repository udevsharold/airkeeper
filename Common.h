//    Copyright (c) 2021 udevs
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, version 3.
//
//    This program is distributed in the hope that it will be useful, but
//    WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//    General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program. If not, see <http://www.gnu.org/licenses/>.

#import <Foundation/Foundation.h>
#import <HBLog.h>
#import <objc/runtime.h>

#define AIRKEEPER_IDENTIFIER @"com.udevs.airkeeper"
#define PREFS_CHANGED_NN @"com.udevs.airkeeper.prefschanged"

#define SETTINGS_BACKUP_PATH @"/var/mobile/Documents/AirKeeper/"
#define SETTINGS_BACKUP_FILE_PREFIX @"AirKeeperProfile-"

#define STRMATCH(a,b) (CFStringCompare(a, b, 0) == kCFCompareEqualTo)
#define GETVAL(dict, k, v) CFDictionaryGetValueIfPresent(dict, k, (const void **)v)

typedef void* CTServerConnectionRef;

typedef NS_ENUM(NSInteger, AKPPolicyType){
	AKPPolicyTypeNone,
	AKPPolicyTypeCellularAllow,
	AKPPolicyTypeWiFiAllow,
	AKPPolicyTypeAllAllow
};
