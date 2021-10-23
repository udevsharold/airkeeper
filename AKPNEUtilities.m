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

+(void)policies:(NSArray <NEPolicy *> **)filteredPolicies ids:(NSArray <NSNumber *> **)filteredPolicyIDs accountIdentifier:(NSString *)accountIdentifier from:(NSDictionary <NSNumber *, NEPolicy *> *)policies{
	NSMutableArray *plc = [NSMutableArray array];
	NSMutableArray *plcid = [NSMutableArray array];
	for (NSNumber *i in policies.allKeys){
		if ([[policies[i].conditions valueForKey:@"accountIdentifier"] containsObject:accountIdentifier]){
			[plcid addObject:i];
			[plc addObject:policies[i]];
		}
	}
	if (filteredPolicies) *filteredPolicies = plc;
	if (filteredPolicyIDs) *filteredPolicyIDs = plcid;
}

#ifndef AKPD

+(NSXPCConnection *)akpdConnection{
	NSXPCConnection *connection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.udevs.akpd" options:NSXPCConnectionPrivileged];
	connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AKPPolicyControlling)];
	[connection resume];
	return connection;
}

+(void)setPolicyWithInfo:(NSDictionary *)info reply:(void (^)(NSError *error))reply{
	[AKPNEUtilities setPolicyWithInfo:info wait:YES reply:^(NSError *error){
		if (reply) reply(error);
	}];
}

+(void)setPolicyWithInfo:(NSDictionary *)info wait:(BOOL)wait reply:(void (^)(NSError *error))reply{
	NSXPCConnection *akpdConnection = [AKPNEUtilities akpdConnection];
	if (akpdConnection){
		[[akpdConnection remoteObjectProxyWithErrorHandler:^(NSError *error){
			HBLogDebug(@"ERROR: %@", error);
			if (reply) reply(error);
			[akpdConnection invalidate];
		}] setPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:info] wait:wait reply:^(NSError *error){
			if (reply) reply(error);
			[akpdConnection invalidate];
		}];
	}else{
		if (reply) reply(AKPERROR(AKP_ERR_INVALID_XPC_CNX, @"Can't establish akpd connection."));
	}
}

+(void)setPolicyWithInfoArray:(NSDictionary *)infos reply:(void (^)(NSError *error))reply{
	NSXPCConnection *akpdConnection = [AKPNEUtilities akpdConnection];
	if (akpdConnection){
		[[akpdConnection remoteObjectProxyWithErrorHandler:^(NSError *error){
			HBLogDebug(@"ERROR: %@", error);
			if (reply) reply(error);
			[akpdConnection invalidate];
		}] setPolicyWithInfoArray:[NSKeyedArchiver archivedDataWithRootObject:infos] reply:^(NSError *error){
			if (reply) reply(error);
			[akpdConnection invalidate];
		}];
	}else{
		if (reply) reply(AKPERROR(AKP_ERR_INVALID_XPC_CNX, @"Can't establish akpd connection."));
	}
}

+(void)setPolicyForAll:(AKPPolicyType)type reply:(void (^)(NSDictionary *updatedPolicies, NSError *error))reply{
	
	NSArray<LSApplicationProxy*>* allInstalledApplications = [[LSApplicationWorkspace defaultWorkspace] atl_allInstalledApplications];
	
	NSDictionary *tamingParams = [AKPUtilities valueForKey:kDaemonTamingKey defaultValue:nil];
	NSMutableDictionary *newPolicies = [NSMutableDictionary dictionary];
	
	__block NSMutableArray *infos = [NSMutableArray array];
	
	for (LSApplicationProxy *proxy in allInstalledApplications){
		
		NSMutableDictionary *policy = [tamingParams[proxy.bundleIdentifier] ?: @{} mutableCopy];
		NSDictionary *newParams = @{
			kPolicingOrder : @(AKPPolicingOrderDaemon),
			kBundleID : proxy.bundleIdentifier,
			kPolicy : @(type)
		};
		[policy addEntriesFromDictionary:newParams];
		NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
		[infos addObject:cleansedPolicy];
		newPolicies[proxy.bundleIdentifier] = cleansedPolicy;
	}
	[AKPNEUtilities setPolicyWithInfoArray:infos reply:^(NSError *error){
		if (reply) reply(newPolicies, error);
	}];
	
}

+(void)initializeSessionAndWait:(BOOL)wait reply:(void (^)(NSError *error))reply{
	NSXPCConnection *akpdConnection = [AKPNEUtilities akpdConnection];
	if (akpdConnection){
		[[akpdConnection remoteObjectProxyWithErrorHandler:^(NSError *error){
			HBLogDebug(@"ERROR: %@", error);
			if (reply) reply(error);
			[akpdConnection invalidate];
		}] initializeSessionAndWait:wait reply:^(NSError *error){
			if (reply) reply(error);
			[akpdConnection invalidate];
		}];
	}else{
		if (reply) reply(AKPERROR(AKP_ERR_INVALID_XPC_CNX, @"Can't establish akpd connection."));
	}
}

#endif
@end
