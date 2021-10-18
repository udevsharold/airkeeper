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

#import "AKPNEUtilities.h"
#import "AKPUtilities.h"
#import "akpd/AKPPolicyControlling-Protocol.h"
#ifndef AKPD
#import <AltList/LSApplicationProxy+AltList.h>
#endif

@implementation AKPNEUtilities

+(NSString *)stringForTrafficRule:(AKPDaemonTrafficRule)rule simple:(BOOL)simple{
	switch (rule) {
		case AKPDaemonTrafficRulePassAllDomains:
		case AKPDaemonTrafficRulePassAllBounds:
			return @"Pass";
		case AKPDaemonTrafficRuleDropDomain:
			return @"Block";
		case AKPDaemonTrafficRulePassDomain:
			return @"Allow";
		case AKPDaemonTrafficRuleDropInbound:
			return simple ? @"Outbound" : @"Outbound Only";
		case AKPDaemonTrafficRuleDropOutbound:
			return simple ? @"Inbound" : @"Inbound Only";
		default:
			return @"Unknown";
	}
}

+(NSArray <NEPolicyRouteRule *>* )policyAsRouteRules:(AKPPolicyType)policy{
	switch (policy) {
		case AKPPolicyTypeNone:{
			NEPolicyRouteRule *cellular = [NEPolicyRouteRule routeRuleWithAction:NEPolicyRouteRuleActionDeny forType:NEPolicyRouteRuleTypeCellular];
			NEPolicyRouteRule *wifi = [NEPolicyRouteRule routeRuleWithAction:NEPolicyRouteRuleActionDeny forType:NEPolicyRouteRuleTypeWiFi];
			return @[cellular, wifi];
		}
		case AKPPolicyTypeCellularAllow:{
			NEPolicyRouteRule *cellular = [NEPolicyRouteRule routeRuleWithAction:NEPolicyRouteRuleActionAllow forType:NEPolicyRouteRuleTypeCellular];
			NEPolicyRouteRule *wifi = [NEPolicyRouteRule routeRuleWithAction:NEPolicyRouteRuleActionDeny forType:NEPolicyRouteRuleTypeWiFi];
			return @[cellular, wifi];
		}
		case AKPPolicyTypeWiFiAllow:{
			NEPolicyRouteRule *cellular = [NEPolicyRouteRule routeRuleWithAction:NEPolicyRouteRuleActionDeny forType:NEPolicyRouteRuleTypeCellular];
			NEPolicyRouteRule *wifi = [NEPolicyRouteRule routeRuleWithAction:NEPolicyRouteRuleActionAllow forType:NEPolicyRouteRuleTypeWiFi];
			return @[cellular, wifi];
		}
		case AKPPolicyTypeAllAllow:
		default:{
			NEPolicyRouteRule *cellular = [NEPolicyRouteRule routeRuleWithAction:NEPolicyRouteRuleActionAllow forType:NEPolicyRouteRuleTypeCellular];
			NEPolicyRouteRule *wifi = [NEPolicyRouteRule routeRuleWithAction:NEPolicyRouteRuleActionAllow forType:NEPolicyRouteRuleTypeWiFi];
			return @[cellular, wifi];
		}
	}
}

#ifndef AKPD

+(NSXPCConnection *)akpdConnection{
	NSXPCConnection *connection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.udevs.akpd" options:NSXPCConnectionPrivileged];
	connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AKPPolicyControlling)];
	[connection resume];
	return connection;
}

+(void)setPolicyWithInfo:(NSDictionary *)info reply:(void (^)(NSError *error))reply{
	NSXPCConnection *akpdConnection = [AKPNEUtilities akpdConnection];
	if (akpdConnection){
		[[akpdConnection remoteObjectProxyWithErrorHandler:^(NSError *error){
			HBLogDebug(@"ERROR: %@", error);
			if (reply) reply(error);
			[akpdConnection invalidate];
		}] setPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:info] reply:^(BOOL success, NSArray <NSNumber *>*policyIDs){
			if (reply) reply(success ? nil : [NSError errorWithDomain:@"com.udevs.akpd" code:1 userInfo:@{@"Error reason":[NSString stringWithFormat:@"Failed to set %@ policy to %@.", info[kLabel], info[kPolicy]]}]);
			[akpdConnection invalidate];
		}];
	}else{
		if (reply) reply([NSError errorWithDomain:@"com.udevs.akpd" code:1 userInfo:@{@"Error reason":@"Can't establish akpd connection."}]);
	}
}

+(void)setPolicyWithInfoArray:(NSDictionary *)infos reply:(void (^)(NSArray <NSNumber *>*successes, NSDictionary *policies, NSError *error))reply{
	NSXPCConnection *akpdConnection = [AKPNEUtilities akpdConnection];
	if (akpdConnection){
		[[akpdConnection remoteObjectProxyWithErrorHandler:^(NSError *error){
			HBLogDebug(@"ERROR: %@", error);
			if (reply) reply(nil, nil, error);
			[akpdConnection invalidate];
		}] setPolicyWithInfoArray:[NSKeyedArchiver archivedDataWithRootObject:infos] reply:^(NSArray <NSNumber *>*successes, NSData *policies){
			if (reply) reply(successes, [NSKeyedUnarchiver unarchiveObjectWithData:policies], nil);
			[akpdConnection invalidate];
		}];
	}else{
		if (reply) reply(nil, nil, [NSError errorWithDomain:@"com.udevs.akpd" code:1 userInfo:@{@"Error reason":@"Can't establish akpd connection."}]);
	}
}

+(void)setPolicyForAll:(AKPPolicyType)type reply:(void (^)(NSArray <NSNumber *>*successes, NSDictionary *policies, NSError *error))reply{
	
	NSArray<LSApplicationProxy*>* allInstalledApplications = [[LSApplicationWorkspace defaultWorkspace] atl_allInstalledApplications];
	
	[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
		__block NSMutableArray *infos = [NSMutableArray array];
		
		for (LSApplicationProxy *proxy in allInstalledApplications){
			NSMutableDictionary *policy = [policies[proxy.bundleIdentifier] ?: @{} mutableCopy];
			NSDictionary *newParams = @{
				kPolicingOrder : @(AKPPolicingOrderDaemon),
				kBundleID : proxy.bundleIdentifier,
				kPolicy : @(type)
			};
			[policy addEntriesFromDictionary:newParams];
			NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
			[infos addObject:cleansedPolicy];
		}
		[AKPNEUtilities setPolicyWithInfoArray:infos reply:^(NSArray <NSNumber *>*successes, NSDictionary *policies, NSError *error){
			if (reply) reply(successes, policies, error);
		}];
	}];
	
}

+(void)readPolicyWithInfo:(NSDictionary *)info reply:(void (^)(AKPPolicyType policy))reply{
	NSXPCConnection *akpdConnection = [AKPNEUtilities akpdConnection];
	if (akpdConnection){
		[[akpdConnection remoteObjectProxyWithErrorHandler:^(NSError *error){
			HBLogDebug(@"ERROR: %@", error);
			if (reply) reply(AKPPolicyTypeAllAllow);
			[akpdConnection invalidate];
		}] readPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:info] reply:^(AKPPolicyType policy){
			if (reply) reply(policy);
			[akpdConnection invalidate];
		}];
	}else{
		if (reply) reply(AKPPolicyTypeAllAllow);
	}
}

+(void)currentPoliciesWithReply:(void (^)(NSDictionary *policies))reply{
	NSXPCConnection *akpdConnection = [AKPNEUtilities akpdConnection];
	if (akpdConnection){
		[[akpdConnection remoteObjectProxyWithErrorHandler:^(NSError *error){
			HBLogDebug(@"ERROR: %@", error);
			if (reply) reply(nil);
			[akpdConnection invalidate];
		}] currentPoliciesWithReply:^(NSData *policies){
			if (reply) reply([NSKeyedUnarchiver unarchiveObjectWithData:policies]);
			[akpdConnection invalidate];
		}];
	}else{
		if (reply) reply(nil);
	}
}

+(void)initializeSessionWithReply:(void (^)(BOOL finished))reply{
	NSXPCConnection *akpdConnection = [AKPNEUtilities akpdConnection];
	if (akpdConnection){
		[[akpdConnection remoteObjectProxyWithErrorHandler:^(NSError *error){
			HBLogDebug(@"ERROR: %@", error);
			if (reply) reply(YES);
			[akpdConnection invalidate];
		}] initializeSessionWithReply:^(BOOL finished){
			if (reply) reply(finished);
			[akpdConnection invalidate];
		}];
	}else{
		if (reply) reply(YES);
	}
}

#endif
@end
