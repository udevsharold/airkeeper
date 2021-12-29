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
#define CLI_UPDATED_PREFS_NN @"com.udevs.airkeeper.prefschanged-cli"
#define PREFS_PATH @"/var/mobile/Library/Preferences/com.udevs.airkeeper.plist"

#define SETTINGS_BACKUP_PATH @"/var/mobile/Documents/AirKeeper/"
#define SETTINGS_BACKUP_FILE_PREFIX @"AirKeeperProfile-"

#define STRMATCH(a,b) (CFStringCompare(a, b, 0) == kCFCompareEqualTo)
#define GETVAL(dict, k, v) CFDictionaryGetValueIfPresent(dict, k, (const void **)v)

#define FetchingDaemonsInfoFinishedNotification @"FetchingDaemonsInfoFinishedNotification"
#define RestoringFinishedNotification @"RestoringFinishedNotification"
#define ExportingProfileFinishedNotification @"ExportingProfileFinishedNotification"
#define ImportingProfileFinishedNotification @"ImportingProfileFinishedNotification"
#define CLIUpdatedPrefsNotification @"CLIUpdatedPrefsNotification"

#define KEEP_ALIVE_FILE @"/var/mobile/Library/Caches/com.udevs.akpd/KeepAlive"

#ifndef PSDefaultCell
#define PSDefaultCell -1
#endif
#ifndef PSSpinnerCell
#define PSSpinnerCell 15
#endif

#define CPU_THROTTLE_HOSTS_NUM 10000
#define CPU_THROTTLE_PERCENTAGE 70

#define MAX_GLOBAL_HOSTS_LIMIT 0 //0=unlimited
#define MAX_DAEMON_HOSTS_LIMIT 0 //0=unlimited

#define kPriority @"priority"
#define kPriorityPrimus @"primus"
#define kPrioritySecundas @"secundas"
#define kPolicingOrder @"policing_order"
#define kLabel @"label"
#define kBin @"bin"
#define kBundleID @"bundle_id"
#define kPath @"path"
#define kPolicy @"policy"
#define kPolicyIDs @"policy_ids"
#define kMachOUUIDs @"macho_uuids"
#define kDomains @"domains"
#define kRule @"rule"
#define kGlobal @"global"
#define kPrimusRule @"primus_rule"
#define kSecundasRule @"secundas_rule"
#define kTertiusRule @"tertius_rule"
#define kPrimusDomains @"primus_domains"
#define kSecundasDomains @"secundas_domains"
#define kTertiusDomains @"tertius_domains"

//Prefs Key
#define kCacheKey @"cache"
#define kDaemonTamingKey @"daemonParams"
#define kDaemonCacheKey @"daemonCache"
#define kAcknowledgedDelayedApplyKey @"acknowledgedDelayedApply"

//Error
typedef NS_ENUM(NSInteger, AKPERRCODE){
	AKP_ERR_SUCCESS,
	AKP_ERR_INVALID_ID,
	AKP_ERR_INVALID_XPC_CNX
};
#define AKPERROR(c, r) [NSError errorWithDomain:@"com.udevs.airkeeper" code:c userInfo:@{NSLocalizedDescriptionKey:r}]


//Alert message
#define delayedApplyMessage @"Depending on your device, high number of domain list might take few minutes to be fully effective. You might notice higher CPU load during this period and that's perfectly normal, it only occurs once whenever you change or apply new domains. You may continue to use the device normally in the meantime."

typedef void* CTServerConnectionRef;

typedef NS_ENUM(NSInteger, AKPPolicyType){
	AKPPolicyTypeNone,
	AKPPolicyTypeCellularAllow,
	AKPPolicyTypeWiFiAllow,
	AKPPolicyTypeAllAllow,
	AKPPolicyTypeLocalNetworkAllow,
	AKPPolicyTypeUnknown = 0xdeadbabe
};

typedef NS_ENUM(NSInteger, AKPReloadSpecifierType){
	AKPReloadSpecifierTypeConnectivity,
	AKPReloadSpecifierTypePerAppVPN
};

typedef NS_ENUM(NSInteger, AKPDaemonTrafficRule){
	AKPDaemonTrafficRulePassAllDomains,
	AKPDaemonTrafficRuleDropDomain,
	AKPDaemonTrafficRulePassDomain,
	AKPDaemonTrafficRulePassAllBounds,
	AKPDaemonTrafficRuleDropInbound,
	AKPDaemonTrafficRuleDropOutbound,
	AKPDaemonTrafficRuleUnknown = 0xdeadbabe
	
};

typedef NS_ENUM(NSInteger, AKPPolicingOrder){
	AKPPolicingOrderDaemon,
	AKPPolicingOrderGlobal
};

typedef NS_ENUM(NSInteger, AKPPolicyMode){
	AKPPolicyModeNonPersist,
	AKPPolicyModePersist,
};
