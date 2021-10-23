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

#import "Common.h"
#import "PrivateHeaders.h"

#ifndef AKPD
#define kCTCellularDataUsagePolicy CFSTR("kCTCellularDataUsagePolicy")
#define kCTWiFiDataUsagePolicy CFSTR("kCTWiFiDataUsagePolicy")
#define kCTCellularDataUsagePolicyDeny CFSTR("kCTCellularDataUsagePolicyDeny")
#define kCTCellularDataUsagePolicyAlwaysAllow CFSTR("kCTCellularDataUsagePolicyAlwaysAllow")

#ifdef __cplusplus
extern "C" {
#endif

CTServerConnectionRef _CTServerConnectionCreate(CFAllocatorRef, void *, void*);
int64_t _CTServerConnectionSetCellularUsagePolicy(CTServerConnectionRef ct, CFStringRef identifier, CFDictionaryRef policies);
int64_t _CTServerConnectionCopyCellularUsagePolicy(CTServerConnectionRef ct, CFStringRef identifier, CFMutableDictionaryRef *policies);
CFStringRef MGCopyAnswer(CFStringRef);

#ifdef __cplusplus
}
#endif
#endif

@interface AKPUtilities : NSObject
#ifndef AKPD
+(CTServerConnectionRef)ctConnection;
+(void)setPolicy:(AKPPolicyType)type forIdentifier:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success;
+(void)setPolicyForAll:(AKPPolicyType)type connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success;
+(AKPPolicyType)readPolicy:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success;
+(NSString *)policyAsString:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success;
+(NSString *)stringForPolicy:(AKPPolicyType)type;
+(void)restoreAllConfigurationsAndWaitInitialize:(BOOL)reinit handler:(void(^)(NSArray <NSError *>*))resultHandler;
+(void)restoreAllPersistentConfigurationsWithHandler:(void(^)(NSArray <NSError *>*))resultHandler;
+(void)restoreAllChanged:(CTServerConnectionRef)ctConnection;
+(NSDictionary *)exportPolicies:(CTServerConnectionRef)ctConnection;
+(void)exportPoliciesTo:(NSString *)file connection:(CTServerConnectionRef)ctConnection;
+(BOOL)importPolicies:(NSDictionary *)policies connection:(CTServerConnectionRef)ctConnection;
+(void)purgeCellularUsagePolicyWithHandler:(void(^)(NSArray <NSError *>*))resultHandler;
+(void)purgeCreatedNetworkConfigurationForPerAppWithHandler:(void(^)(NSArray <NSError *>*))resultHandler;
+(void)purgeNetworkConfigurationNamed:(NSString *)name handler:(void(^)(NSArray <NSError *>*))resultHandler;
+(void)completeProfileExport:(CTServerConnectionRef)ctConnection handler:(void(^)(NSDictionary *, NSArray <NSError *>*))resultHandler;
+(void)completeProfileImport:(NSDictionary *)profile connection:(CTServerConnectionRef)ctConnection waitInitialize:(BOOL)reinit handler:(void(^)(NSArray <NSError *>*))resultHandler;
+(void)exportProfileTo:(NSString *)file connection:(CTServerConnectionRef)ctConnection handler:(void(^)(NSData *, NSArray <NSError *>*))resultHandler;
#ifndef AKP
+(NSString*)osBuildVersion;
+(NSString *)deviceUDID;
+(NSString *)hashedAck256;
#endif
#endif
+(NSDictionary *)prefs;
+(void)removeKey:(NSString *)key;
+(id)valueForKey:(NSString *)key defaultValue:(id)defaultValue;
+(id)valueForCacheSubkey:(NSString *)subkey defaultValue:(id)defaultValue;
+(void)setValue:(id)value forKey:(NSString *)key;
+(void)setCacheValue:(id)value forSubkey:(NSString *)subkey;
+(id)valueForDaemonCacheSubkey:(NSString *)subkey defaultValue:(id)defaultValue;
+(id)valueForDaemonTamingKey:(NSString *)key defaultValue:(id)defaultValue;
+(void)setDaemonCacheValue:(id)value forSubkey:(NSString *)subkey;
+(void)setDaemonTamingValue:(id)value forKey:(NSString *)key;
+(NSDictionary *)cleansedPolicyDict:(NSDictionary *)policy;
@end
