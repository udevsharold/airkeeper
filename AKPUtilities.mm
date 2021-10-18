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

#import "AKPUtilities.h"
#ifndef AKPD
#import "AKPNEUtilities.h"
#import <AltList/LSApplicationProxy+AltList.h>
#import "AKPNetworkConfigurationUtilities.h"
#import "AKPPerAppVPNConfiguration.h"
#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>
#endif

#define CF2NS(cfstr) (__bridge NSString *)cfstr

@implementation AKPUtilities

#ifndef AKPD
+(CTServerConnectionRef)ctConnection{
	return _CTServerConnectionCreate(kCFAllocatorDefault, NULL, NULL);
}

+(void)setPolicy:(AKPPolicyType)type forIdentifier:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success{
	if (ctConnection){
		
		NSMutableDictionary *policies = [NSMutableDictionary dictionary];
		
		switch (type) {
			case AKPPolicyTypeNone:{
				policies[CF2NS(kCTCellularDataUsagePolicy)] = CF2NS(kCTCellularDataUsagePolicyDeny);
				policies[CF2NS(kCTWiFiDataUsagePolicy)] = CF2NS(kCTCellularDataUsagePolicyDeny);
				break;
			}
			case AKPPolicyTypeCellularAllow:{
				policies[CF2NS(kCTCellularDataUsagePolicy)] = CF2NS(kCTCellularDataUsagePolicyAlwaysAllow);
				policies[CF2NS(kCTWiFiDataUsagePolicy)] = CF2NS(kCTCellularDataUsagePolicyDeny);
				break;
			}
			case AKPPolicyTypeWiFiAllow:{
				policies[CF2NS(kCTCellularDataUsagePolicy)] = CF2NS(kCTCellularDataUsagePolicyDeny);
				policies[CF2NS(kCTWiFiDataUsagePolicy)] = CF2NS(kCTCellularDataUsagePolicyAlwaysAllow);
				break;
			}
			case AKPPolicyTypeAllAllow:{
				policies[CF2NS(kCTCellularDataUsagePolicy)] = CF2NS(kCTCellularDataUsagePolicyAlwaysAllow);
				policies[CF2NS(kCTWiFiDataUsagePolicy)] = CF2NS(kCTCellularDataUsagePolicyAlwaysAllow);
				break;
			}
			default:
				return;
		}
		if (_CTServerConnectionSetCellularUsagePolicy(ctConnection, (__bridge CFStringRef)identifier, (__bridge CFMutableDictionaryRef)policies)){
			if (success) *success = NO;
		}else{
			if (success) *success = YES;
		}
		
	}
}

+(void)setPolicyForAll:(AKPPolicyType)type connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success{
	if (ctConnection){
		BOOL suc = NO;
		NSArray<LSApplicationProxy*>* allInstalledApplications = [[LSApplicationWorkspace defaultWorkspace] atl_allInstalledApplications];
		for (LSApplicationProxy *proxy in allInstalledApplications){
			if ([proxy atl_isHidden]) continue;
			if (type != [AKPUtilities readPolicy:proxy.bundleIdentifier connection:ctConnection success:nil]){
				[AKPUtilities setPolicy:type forIdentifier:proxy.bundleIdentifier connection:ctConnection success:&suc];
			}
			if (success && *success) *success = suc;
		}
	}
}

+(AKPPolicyType)readPolicy:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success{
	BOOL cellularAllowed = YES;
	BOOL wifiAllowed = YES;
	if (ctConnection){
		CFMutableDictionaryRef policies = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		if (_CTServerConnectionCopyCellularUsagePolicy(ctConnection, (__bridge CFStringRef)identifier,  &policies)){
			if (success) *success = NO;
		}else{
			if (success) *success = YES;
			
			CFStringRef strval;
			
			if (GETVAL(policies, kCTCellularDataUsagePolicy, &strval) && STRMATCH(strval, kCTCellularDataUsagePolicyDeny)){
				cellularAllowed = NO;
			}
			
			if (GETVAL(policies, kCTWiFiDataUsagePolicy, &strval) && STRMATCH(strval, kCTCellularDataUsagePolicyDeny)){
				wifiAllowed = NO;
			}
			
			if (strval) CFRelease(strval);
			if (policies) CFRelease(policies);
		}
		
	}
	
	if (cellularAllowed && wifiAllowed){
		return AKPPolicyTypeAllAllow;
	}else if (cellularAllowed && !wifiAllowed){
		return AKPPolicyTypeCellularAllow;
	}else if (!cellularAllowed && wifiAllowed){
		return AKPPolicyTypeWiFiAllow;
	}else{
		return AKPPolicyTypeNone;
	}
}

+(NSString *)policyAsString:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success{
	if (ctConnection){
		BOOL suc = NO;
		AKPPolicyType type = [AKPUtilities readPolicy:identifier connection:ctConnection success:&suc];
		if (success) *success = suc;
		return [AKPUtilities stringForPolicy:type];
	}
	return [AKPUtilities stringForPolicy:AKPPolicyTypeAllAllow];
}

+(NSString *)stringForPolicy:(AKPPolicyType)type{
	switch (type) {
		case AKPPolicyTypeNone:{
			return @"Off";
		}
		case AKPPolicyTypeCellularAllow:{
			return @"Mobile Data";
		}
		case AKPPolicyTypeWiFiAllow:{
			return @"Wi-Fi";
		}
		case AKPPolicyTypeAllAllow:
		default:
			return @"Wi-Fi & Mobile Data";
	}
}

+(void)restoreAllChanged:(CTServerConnectionRef)ctConnection{
	NSArray<LSApplicationProxy*>* allInstalledApplications = [[LSApplicationWorkspace defaultWorkspace] atl_allInstalledApplications];
	for (LSApplicationProxy *proxy in allInstalledApplications){
		if ([proxy atl_isHidden]) continue;
		if ([AKPUtilities readPolicy:proxy.bundleIdentifier connection:ctConnection success:nil] != AKPPolicyTypeAllAllow){
			[AKPUtilities setPolicy:AKPPolicyTypeAllAllow forIdentifier:proxy.bundleIdentifier connection:ctConnection success:nil];
		}
	}
}

+(void)restoreAllConfigurationsWithHandler:(void(^)(NSArray <NSError *>*))resultHandler{
	__block NSMutableArray *errors = [NSMutableArray array];
	[AKPUtilities purgeCellularUsagePolicyWithHandler:^(NSArray <NSError *>*firstErrors){
		if (firstErrors.count > 0) [errors addObjectsFromArray:firstErrors];
		[AKPUtilities purgeCreatedNetworkConfigurationForPerAppWithHandler:^(NSArray <NSError *>*secondErrors){
			if (secondErrors.count > 0) [errors addObjectsFromArray:secondErrors];
			[AKPUtilities removeKey:@"daemonTamingValue"];
			[AKPNEUtilities initializeSessionWithReply:^(BOOL finished){
				if (resultHandler) resultHandler(errors);
			}];
		}];
	}];
	
}

+(void)purgeCellularUsagePolicyWithHandler:(void(^)(NSArray <NSError *>*))resultHandler{
	[AKPUtilities purgeNetworkConfigurationNamed:@"com.apple.commcenter.ne.cellularusage" handler:^(NSArray <NSError *>*errors){
		if (resultHandler) resultHandler(errors);
	}];
}

+(void)purgeCreatedNetworkConfigurationForPerAppWithHandler:(void(^)(NSArray <NSError *>*))resultHandler{
	[AKPNetworkConfigurationUtilities loadConfigurationsWithCompletion:^(NSArray * configurations, NSError * error){
		__block NSMutableArray *errors = [NSMutableArray array];
		__block NSUInteger idx = 1;
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name contains %@", @"(AirKeeper)"];
		NSArray *theConfigs = [configurations filteredArrayUsingPredicate:predicate];
		if (theConfigs.count > 0){
			for (NEConfiguration *config in theConfigs){
				[AKPNetworkConfigurationUtilities removeConfiguration:config handler:^(NSError *error){
					if (error) [errors addObject:error];
					if (idx >= theConfigs.count && resultHandler) resultHandler(errors);
					idx++;
				}];
			}
		}else{
			if (resultHandler) resultHandler(errors);
		}
	}];
}

+(void)purgeNetworkConfigurationNamed:(NSString *)name handler:(void(^)(NSArray <NSError *>*))resultHandler{
	[AKPNetworkConfigurationUtilities loadConfigurationsWithCompletion:^(NSArray * configurations, NSError * error){
		__block NSMutableArray *errors = [NSMutableArray array];
		__block NSUInteger idx = 1;
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name == %@", name];
		NSArray *theConfigs = [configurations filteredArrayUsingPredicate:predicate];
		if (theConfigs.count > 0){
			for (NEConfiguration *config in theConfigs){
				[AKPNetworkConfigurationUtilities removeConfiguration:config handler:^(NSError *error){
					if (error) [errors addObject:error];
					if (idx >= theConfigs.count && resultHandler) resultHandler(errors);
					idx++;
				}];
			}
		}else{
			if (resultHandler) resultHandler(errors);
		}
	}];
}

+(NSDictionary *)exportPolicies:(CTServerConnectionRef)ctConnection{
	NSMutableDictionary *policies = [NSMutableDictionary dictionary];
	if (ctConnection){
		NSArray<LSApplicationProxy*>* allInstalledApplications = [[LSApplicationWorkspace defaultWorkspace] atl_allInstalledApplications];
		for (LSApplicationProxy *proxy in allInstalledApplications){
			if ([proxy atl_isHidden]) continue;
			AKPPolicyType type = [AKPUtilities readPolicy:proxy.bundleIdentifier connection:ctConnection success:nil];
			if (type != AKPPolicyTypeAllAllow){
				policies[proxy.bundleIdentifier] = @(type);
			}
		}
	}
	return policies.copy;
}

+(void)exportPoliciesTo:(NSString *)file connection:(CTServerConnectionRef)ctConnection{
	if (ctConnection){
		NSDictionary *policies = [AKPUtilities exportPolicies:ctConnection];
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@{@"policies":policies}];
		[data writeToFile:file atomically:YES];
	}
}

+(void)completeProfileExport:(CTServerConnectionRef)ctConnection handler:(void(^)(NSDictionary *, NSArray <NSError *>*))resultHandler{
	
	__block NSMutableDictionary *completeProfile = [NSMutableDictionary dictionary];
	__block NSMutableDictionary *appRules = [NSMutableDictionary dictionary];
	
	[AKPNetworkConfigurationUtilities loadConfigurationsWithCompletion:^(NSArray * configurations, NSError * error){
		__block NSMutableArray *errors = [NSMutableArray array];
		__block NSUInteger idx = 1;
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name contains %@", @"(AirKeeper)"];
		NSArray *theConfigs = [configurations filteredArrayUsingPredicate:predicate];
		if (theConfigs.count > 0){
			for (NEConfiguration *neConfig in theConfigs){
				
				if (error) [errors addObject:error];
				
				NSMutableDictionary *perAppConfig = [NSMutableDictionary dictionary];
				for (NEAppRule *rule in neConfig.appVPN.appRules){
					perAppConfig[rule.matchSigningIdentifier] = @{
						@"matchDomains" : rule.matchDomains ?: [NSNull null],
						@"disconnectOnSleep" : @(neConfig.appVPN.protocol.disconnectOnSleep)
					};
				}
				appRules[neConfig.appVPN.protocol.identifier] = perAppConfig.copy;
				
				if (idx >= theConfigs.count){
					if (ctConnection){
						completeProfile[@"policies"] = [AKPUtilities exportPolicies:ctConnection];
					}
					completeProfile[@"perAppVPNs"] = appRules.copy;
					NSDictionary *daemonTamingCache = [AKPUtilities valueForKey:@"daemonTamingValue" defaultValue:nil];
					if (daemonTamingCache){
						completeProfile[@"policies_non_persistent"] = daemonTamingCache;
					}
					if (resultHandler) resultHandler(completeProfile.copy, errors);
					HBLogDebug(@"Exported profile");
				}
				idx++;
			}
		}else{
			if (ctConnection){
				completeProfile[@"policies"] = [AKPUtilities exportPolicies:ctConnection];
			}
			NSDictionary *daemonTamingCache = [AKPUtilities valueForKey:@"daemonTamingValue" defaultValue:nil];
			if (daemonTamingCache){
				completeProfile[@"policies_non_persistent"] = daemonTamingCache;
			}
			if (resultHandler) resultHandler(completeProfile.copy, errors);
			HBLogDebug(@"Empty ne profile, some not exported");
		}
	}];
}

+(void)exportProfileTo:(NSString *)file connection:(CTServerConnectionRef)ctConnection handler:(void(^)(NSData *, NSArray <NSError *>*))resultHandler{
	if (ctConnection){
		[AKPUtilities completeProfileExport:ctConnection handler:^(NSDictionary *exportedProfile, NSArray <NSError *>*errors){
			NSData *data = [NSKeyedArchiver archivedDataWithRootObject:exportedProfile];
			[data writeToFile:file atomically:YES];
			if (resultHandler) resultHandler(data, errors);
		}];
	}
}

+(void)completeProfileImport:(NSDictionary *)profile connection:(CTServerConnectionRef)ctConnection handler:(void(^)(NSArray <NSError *>*))resultHandler{
	[AKPUtilities restoreAllConfigurationsWithHandler:^(NSArray <NSError *>*errors){
		[AKPNetworkConfigurationUtilities loadConfigurationsWithCompletion:^(NSArray * configurations, NSError * error){
			
			__block NSMutableArray *errors = [NSMutableArray array];
			__block NSUInteger idx = 0;
			
			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.VPN != nil AND SELF.appVPN == nil"];
			NSArray *installedVPNs = [configurations filteredArrayUsingPredicate:predicate];
			NSArray *installedVPNIdentifiers = [installedVPNs valueForKeyPath:@"VPN.protocol.identifier"];
			
			NEConfiguration *dummyConfig = [[NEConfiguration alloc] initWithName:@"Airkeeper Dummy Per-App" grade:NEConfigurationGradeEnterprise];
			
			NSDictionary *perAppVPNs = profile[@"perAppVPNs"];
			NSDictionary *policies = profile[@"policies"];
			NSDictionary *policies_non_persistent = profile[@"policies_non_persistent"];
			
			NSUInteger totalExpectedOperations = 0;
			for (NSDictionary *firstLevel in perAppVPNs.allKeys){
				totalExpectedOperations = totalExpectedOperations + ((NSDictionary *)perAppVPNs[firstLevel]).allKeys.count - 1;
			}
			
			if (perAppVPNs.allKeys.count > 0){
				for (NSUUID *configID in perAppVPNs.allKeys){
					NSDictionary *perAppConfig = perAppVPNs[configID];
					for (NSString *perAppConfigID in perAppConfig.allKeys){
						if ([installedVPNIdentifiers containsObject:configID]){
							AKPPerAppVPNConfiguration *akpPerAppVPNConfig = [AKPPerAppVPNConfiguration new];
							[akpPerAppVPNConfig setValue:configurations forKey:@"_configurations"];
							akpPerAppVPNConfig.bundleIdentifier = perAppConfigID;
							
							NSUInteger idxOfMasterConfig = [installedVPNIdentifiers indexOfObject:configID];
							if (idxOfMasterConfig != NSNotFound){
								NSArray *domains = [perAppConfig[perAppConfigID][@"matchDomains"] isEqual:[NSNull null]] ? nil : perAppConfig[perAppConfigID][@"matchDomains"];
								NSString *path = [perAppConfig[perAppConfigID][@"path"] isEqual:[NSNull null]] ? nil : perAppConfig[perAppConfigID][@"path"];
								BOOL disconnectOnSleep = perAppConfig[perAppConfigID][@"disconnectOnSleep"] ? [perAppConfig[perAppConfigID][@"disconnectOnSleep"] boolValue] : NO;
								
								[akpPerAppVPNConfig switchConfig:dummyConfig to:installedVPNs[idxOfMasterConfig] domains:domains path:path disconnectOnSleep:disconnectOnSleep completion:^(NSError *error){
									if (error) [errors addObject:error];
									if (idx >= totalExpectedOperations){
										[AKPUtilities importPolicies:policies connection:ctConnection];
										if (policies_non_persistent){
											[AKPUtilities setValue:policies_non_persistent forKey:@"daemonTamingValue"];
											[AKPNEUtilities initializeSessionWithReply:^(BOOL finished){
												HBLogDebug(@"AKPDaemon initializing finished");
												if (resultHandler) resultHandler(errors);
											}];
										}else{
											if (resultHandler) resultHandler(errors);
										}
									}
								}];
							}
						}
						idx++;
					}
				}
			}else{
				if (ctConnection){
					[AKPUtilities importPolicies:policies connection:ctConnection];
				}
				if (policies_non_persistent){
					[AKPUtilities setValue:policies_non_persistent forKey:@"daemonTamingValue"];
					[AKPNEUtilities initializeSessionWithReply:^(BOOL finished){
						HBLogDebug(@"AKPDaemon initializing finished");
						if (resultHandler) resultHandler(errors);
					}];
				}else{
					if (resultHandler) resultHandler(errors);
				}
			}
		}];
	}];
}

+(BOOL)importPolicies:(NSDictionary *)policies connection:(CTServerConnectionRef)ctConnection{
	BOOL suc = NO;
	BOOL success = YES;
	NSArray *identifiers = policies.allKeys;
	if (ctConnection){
		NSArray<LSApplicationProxy*>* allInstalledApplications = [[LSApplicationWorkspace defaultWorkspace] atl_allInstalledApplications];
		for (LSApplicationProxy *proxy in allInstalledApplications){
			if ([proxy atl_isHidden]) continue;
			AKPPolicyType type = [AKPUtilities readPolicy:proxy.bundleIdentifier connection:ctConnection success:nil];
			if ([identifiers containsObject:proxy.bundleIdentifier] && type != [policies[proxy.bundleIdentifier] intValue]){
				[AKPUtilities setPolicy:[policies[proxy.bundleIdentifier] intValue] forIdentifier:proxy.bundleIdentifier connection:ctConnection success:&suc];
			}else if (type != AKPPolicyTypeAllAllow){
				[AKPUtilities setPolicy:AKPPolicyTypeAllAllow forIdentifier:proxy.bundleIdentifier connection:ctConnection success:&suc];
			}
			if (!suc) success = suc;
		}
	}
	return success ?: (identifiers.count <= 0);
}

#ifndef AKP
+(NSString*)osBuildVersion{
	return (__bridge NSString *)MGCopyAnswer(CFSTR("BuildVersion"));
}

+(NSString *)deviceUDID{
	return (__bridge NSString *)MGCopyAnswer(CFSTR("UniqueDeviceID"));
}

+(NSString *)hashedAck256{
	static NSMutableString *ret;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		const char* str = [NSString stringWithFormat:@"%@-%@", [AKPUtilities deviceUDID], [AKPUtilities osBuildVersion]].UTF8String;
		unsigned char result[CC_SHA256_DIGEST_LENGTH];
		CC_SHA256(str, (CC_LONG)strlen(str), result);
		ret = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
		for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++){
			[ret appendFormat:@"%02x",result[i]];
		}
	});
	return ret;
}
#endif

#endif

+(void)_writePrefsToDiskAsMobile:(NSDictionary *)prefs{
	[[NSFileManager defaultManager] createFileAtPath:PREFS_PATH contents:[NSPropertyListSerialization dataFromPropertyList:prefs format:NSPropertyListXMLFormat_v1_0 errorDescription:nil] attributes:@{
		NSFileGroupOwnerAccountName : @"mobile",
		NSFileOwnerAccountName : @"mobile"
	}];
}

+(void)removeKey:(NSString *)key{
	NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
	[prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREFS_PATH]];
	if (prefs[key]){
		[prefs removeObjectForKey:key];
		[AKPUtilities _writePrefsToDiskAsMobile:prefs];
	}
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NN, NULL, NULL, YES);
}

+(id)valueForKey:(NSString *)key defaultValue:(id)defaultValue{
	NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
	[prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREFS_PATH]];
	return prefs[key] ?: defaultValue;
}

+(id)valueForCacheSubkey:(NSString *)subkey defaultValue:(id)defaultValue{
	NSDictionary *cached = [AKPUtilities valueForKey:@"cacheValue" defaultValue:nil];
	return cached[subkey] ?: defaultValue;
}

+(id)valueForDaemonCacheSubkey:(NSString *)subkey defaultValue:(id)defaultValue{
	NSDictionary *cached = [AKPUtilities valueForKey:@"daemonCacheValue" defaultValue:nil];
	return cached[subkey] ?: defaultValue;
}

+(id)valueForDaemonTamingKey:(NSString *)key defaultValue:(id)defaultValue{
	NSDictionary *cached = [AKPUtilities valueForKey:@"daemonTamingValue" defaultValue:nil];
	return cached[key] ?: defaultValue;
}

+(void)setValue:(id)value forKey:(NSString *)key{
	NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
	[prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREFS_PATH]];
	[prefs setObject:value forKey:key];
	[AKPUtilities _writePrefsToDiskAsMobile:prefs];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NN, NULL, NULL, YES);
}

+(void)setCacheValue:(id)value forSubkey:(NSString *)subkey{
	id cachedvalue = [AKPUtilities valueForKey:@"cacheValue" defaultValue:nil];
	NSMutableDictionary *cached = cachedvalue ? ((NSDictionary *)cachedvalue).mutableCopy : [NSMutableDictionary dictionary];
	cached[subkey] = value;
	[AKPUtilities setValue:cached forKey:@"cacheValue"];
}

+(void)setDaemonCacheValue:(id)value forSubkey:(NSString *)subkey{
	id cachedvalue = [AKPUtilities valueForKey:@"daemonCacheValue" defaultValue:nil];
	NSMutableDictionary *cached = cachedvalue ? ((NSDictionary *)cachedvalue).mutableCopy : [NSMutableDictionary dictionary];
	cached[subkey] = value;
	[AKPUtilities setValue:cached forKey:@"daemonCacheValue"];
}

+(void)setDaemonTamingValue:(id)value forKey:(NSString *)key{
	id cachedvalue = [AKPUtilities valueForKey:@"daemonTamingValue" defaultValue:nil];
	NSMutableDictionary *cached = cachedvalue ? ((NSDictionary *)cachedvalue).mutableCopy : [NSMutableDictionary dictionary];
	cached[key] = value;
	[AKPUtilities setValue:cached forKey:@"daemonTamingValue"];
}

+(NSDictionary *)cleansedPolicyDict:(NSDictionary *)policy{
	NSArray *unwantedKeys = @[
		kBin,
		kPolicyIDs,
		kMachOUUIDs
	];
	NSMutableDictionary *cleansedPolicy = policy.mutableCopy;
	for (NSString *key in policy.allKeys){
		if ([unwantedKeys containsObject:key]){
			[cleansedPolicy removeObjectForKey:key];
		}
	}
	return cleansedPolicy.copy;
}

@end
