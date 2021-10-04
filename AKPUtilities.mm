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
#import <AltList/LSApplicationProxy+AltList.h>
#import <dlfcn.h>

#define CF2NS(cfstr) (__bridge NSString *)cfstr

@implementation AKPUtilities

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
		[policies writeToFile:file atomically:YES];
	}
}

+(BOOL)importPolicies:(NSDictionary *)policies connection:(CTServerConnectionRef)ctConnection{
	BOOL success = NO;
	if (ctConnection){
		for (NSString *identifier in policies.allKeys){
			[AKPUtilities setPolicy:[policies[identifier] intValue] forIdentifier:identifier connection:ctConnection success:&success];
		}
	}
	return success;
}
@end
