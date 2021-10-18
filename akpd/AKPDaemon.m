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

#import "AKPDaemon.h"
#import "AKPPolicyControlling-Protocol.h"
#import "../AKPUtilities.h"
#import "../AKPNEUtilities.h"

@implementation AKPDaemon

+(instancetype)sharedInstance{
	static AKPDaemon *sharedInstance = nil;
	static dispatch_once_t token = 0;
	dispatch_once(&token, ^{
		sharedInstance = [self new];
	});
	return sharedInstance;
}

-(instancetype)init{
	if (self = [super init]){
		
		xpc_set_event_stream_handler("com.apple.distnoted.matching", NULL, ^(xpc_object_t _Nonnull object) {
			const char *event = xpc_dictionary_get_string(object, XPC_EVENT_KEY_NAME);
			
			if (strcmp(event, "ApplicationInstalled") == 0){
				xpc_object_t userInfo = xpc_dictionary_get_value(object, "UserInfo");
				if (userInfo && xpc_get_type(userInfo) == XPC_TYPE_DICTIONARY){
					BOOL isPlaceholder = xpc_dictionary_get_bool(userInfo, "isPlaceholder");
					if (!isPlaceholder){
						xpc_object_t bundleIDs = xpc_dictionary_get_value(userInfo, "bundleIDs");
						if (bundleIDs && xpc_get_type(bundleIDs) == XPC_TYPE_ARRAY){
							
							xpc_array_apply(bundleIDs, ^_Bool(size_t index, xpc_object_t bundleID){
								if (xpc_get_type(bundleID) == XPC_TYPE_STRING){
									[self handleAppInstalled:[NSString stringWithUTF8String:xpc_string_get_string_ptr(bundleID)]];
								}
								return YES;
							});
							
						}
					}
				}
			}else if (strcmp(event, "ApplicationUninstalled") == 0){
				xpc_object_t userInfo = xpc_dictionary_get_value(object, "UserInfo");
				if (userInfo && xpc_get_type(userInfo) == XPC_TYPE_DICTIONARY){
					xpc_object_t bundleIDs = xpc_dictionary_get_value(userInfo, "bundleIDs");
					if (bundleIDs && xpc_get_type(bundleIDs) == XPC_TYPE_ARRAY){
						
						xpc_array_apply(bundleIDs, ^_Bool(size_t index, xpc_object_t bundleID){
							if (xpc_get_type(bundleID) == XPC_TYPE_STRING){
								[self handleAppUninstalled:[NSString stringWithUTF8String:xpc_string_get_string_ptr(bundleID)]];
							}
							return YES;
						});
						
					}
				}
			}
		});
		
		_policySession = [[NEPolicySession alloc] init];
		_policySession.priority = NEPolicySessionPriorityControl;
		_policies = [NSMutableDictionary dictionary];
		[self initializeSessionWithReply:^(BOOL finished){
		}];
		
	}
	return self;
}

-(void)terminateIfNecessary{
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *key in _policies.allKeys){
		NSArray *ids = _policies[key][kPolicyIDs];
		if (ids.count > 0){
			return;
		}
	}
	[fm removeItemAtPath:KEEP_ALIVE_FILE error:nil];
	exit(EXIT_SUCCESS);
}

-(void)queueTerminationIfNecessaryWithDelay:(int64_t)delay{
	self.initialized = YES;
	if (_terminationVerificationBlock) dispatch_block_cancel(_terminationVerificationBlock);
	_terminationVerificationBlock = dispatch_block_create(0, ^{
		[self terminateIfNecessary];
		_terminationVerificationBlock = nil;
	});
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), _terminationVerificationBlock);
}

-(void)handleAppInstalled:(NSString *)bundleID{
	HBLogDebug(@"handleAppInstalled: %@", bundleID);
	if (_policies[bundleID]){
		NSDictionary *daemonTamingCache = [AKPUtilities valueForKey:@"daemonTamingValue" defaultValue:nil];
		[self setPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:daemonTamingCache[bundleID]] reply:^(BOOL success, NSArray <NSNumber *>*policyIDs){
		}];
	}
}

-(void)handleAppUninstalled:(NSString *)bundleID{
	HBLogDebug(@"handleAppUninstalled: %@", bundleID);
	if (_policies[bundleID]){
		for (NSNumber *policyID in _policies[bundleID][kPolicyIDs]){
			[_policySession removePolicyWithID:[policyID unsignedLongValue]];
		}
		[_policies removeObjectForKey:bundleID];
		[_policySession apply];
	}
}

-(void)initializeSessionWithReply:(void (^)(BOOL finished))reply{
	
	[_policySession removeAllPolicies];
	_policies = [NSMutableDictionary dictionary];
	[_policySession apply];
	
	NSDictionary *daemonTamingCache = [AKPUtilities valueForKey:@"daemonTamingValue" defaultValue:nil];
	if (daemonTamingCache){
		NSArray *allKeys = daemonTamingCache.allKeys;
		__block NSUInteger idx = 1;
		if (allKeys.count > 0){
			for (NSString *key in allKeys){
				[self setPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:daemonTamingCache[key]] reply:^(BOOL success, NSArray <NSNumber *>*policyIDs){
					if (idx >= allKeys.count){
						if (reply) reply(YES);
					}
					idx++;
				}];
			}
		}else{
			if (reply) reply(YES);
		}
	}else{
		if (reply) reply(YES);
	}
}

-(NSString *)uniqueIdentifier:(NSDictionary *)info{
	NSString *uniqueIdentifier;
	if ([info[kPath] length] > 0){
		uniqueIdentifier = info[kPath];
	}else if ([info[kBundleID] length] > 0){
		uniqueIdentifier = info[kBundleID];
	}else if ([info[kLabel] length] > 0){
		uniqueIdentifier = info[kLabel];
	}
	return uniqueIdentifier;
}

-(NSArray <NSUUID *>*)machOUUIDs:(NSDictionary *)info{
	NSMutableArray *machOUUIDs = [NSMutableArray array];
	if ([info[kPath] length] > 0){
		[machOUUIDs addObjectsFromArray:[NEProcessInfo copyUUIDsForExecutable:info[kPath]]];
	}else if ([info[kBundleID] length] > 0){
		[machOUUIDs addObjectsFromArray:[NEProcessInfo copyUUIDsForBundleID:info[kBundleID] uid:0]];
	}else if ([info[kLabel] length] > 0){
		[machOUUIDs addObjectsFromArray:[NEProcessInfo copyUUIDsForBundleID:info[kLabel] uid:0]];
	}
	return machOUUIDs.copy;
}

-(NSString *)sanitizeDomainString:(NSString *)rawDomain{
	NSString *sanitizedDomain = [rawDomain stringByReplacingOccurrencesOfString:@"^\\s+|\\s+$" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, rawDomain.length)];
	sanitizedDomain = [sanitizedDomain stringByReplacingOccurrencesOfString:@"\\s{1,}" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, sanitizedDomain.length)];
	return [sanitizedDomain hasPrefix:@"#"] ? nil : sanitizedDomain;
}

-(AKPPolicingOrder)policingOrder:(NSDictionary *)info{
	return [info[kPolicingOrder] ?: @(AKPPolicingOrderDaemon) intValue];
}

-(void)setPolicyWithInfoArray:(NSData *)data reply:(void (^)(NSArray <NSNumber *>*successes, NSData *policies))reply{
	NSArray *infos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	__block NSMutableArray *successes = [NSMutableArray array];
	__block NSUInteger completedIdx = 1;
	NSUInteger expectedOperations = infos.count;
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *info in infos){
		[weakSelf setPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:info] reply:^(BOOL success, NSArray <NSNumber *>*policyIDs){
			[successes addObject:@(success)];
			if (completedIdx >= expectedOperations){
				if (reply) reply(successes, [NSKeyedArchiver archivedDataWithRootObject:_policies]);
			}
			completedIdx++;
		}];
	}
}


-(void)setPolicyWithInfo:(NSData *)data reply:(void (^)(BOOL success, NSArray <NSNumber *>*policyIDs))reply{
	NSDictionary *info = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	// path > bundle_id > label
	NSString *uniqueIdentifier = [self uniqueIdentifier:info];
	if (uniqueIdentifier.length <= 0){
		if (reply) reply(NO, nil);
		return;
	}
	
	AKPPolicingOrder policingOrder = [self policingOrder:info];
	
	NSMutableArray *policyIDs = [NSMutableArray array];
	
	
	switch (policingOrder) {
			
#pragma mark AKPPolicingOrderDaemon
			
		case AKPPolicingOrderDaemon:{
			
			AKPDaemonTrafficRule secundasRule = [info[kSecundasRule] ?: @(AKPDaemonTrafficRulePassAllDomains) intValue];
			AKPDaemonTrafficRule tertiusRule = [info[kTertiusRule] ?: @(AKPDaemonTrafficRulePassAllBounds) intValue];
			
			NSArray *domains = info[kPrimusDomains] ?: @[];
			NSArray *machOUUIDs = [self machOUUIDs:info];
			
			AKPPolicyType policy = [info[kPolicy] ?: @(AKPPolicyTypeAllAllow) intValue];
			
			void (^revokePrevPolicies)() = ^{
				for (NSNumber *policyID in _policies[uniqueIdentifier][kPolicyIDs]){
					[_policySession removePolicyWithID:[policyID unsignedLongValue]];
				}
				[_policies removeObjectForKey:uniqueIdentifier];
			};
			
			if (machOUUIDs){
				for (NSUUID *uuid in machOUUIDs){
					
					//first order - net connectivity
					if (policy != AKPPolicyTypeAllAllow){
						NSMutableArray <NEPolicyCondition *> *primusPolicyConditions = [NSMutableArray array];
						[primusPolicyConditions addObject:[NEPolicyCondition effectiveApplication:uuid]];
						NEPolicyResult *primusPolicyResult = [NEPolicyResult routeRules:[AKPNEUtilities policyAsRouteRules:policy]];
						NEPolicy *primusPolicy = [[NEPolicy alloc] initWithOrder:500 result:primusPolicyResult conditions:primusPolicyConditions.copy];
						[policyIDs addObject:@([_policySession addPolicy:primusPolicy])];
					}
					
					//second order - domains
					if (secundasRule != AKPDaemonTrafficRulePassAllDomains){
						for (NSString *rawDomain in domains){
							
							NSString *domain = rawDomain;
							
							NSArray *explodedDomain = [[self sanitizeDomainString:rawDomain] componentsSeparatedByString:@" "];
							if (explodedDomain.count > 1){ //127.0.0.1 apple.com
								domain = explodedDomain[1];
							}
							
							if (domain.length <= 0) continue;
							
							NSMutableArray <NEPolicyCondition *> *secundasPolicyConditions = [NSMutableArray array];
							[secundasPolicyConditions addObject:[NEPolicyCondition effectiveApplication:uuid]];
							NEPolicyCondition *secundasPolicyCondition = [NEPolicyCondition domain:domain];
							secundasPolicyCondition.negative = !(secundasRule == AKPDaemonTrafficRuleDropDomain);
							[secundasPolicyConditions addObject:secundasPolicyCondition];
							NEPolicyResult *secundasPolicyResult = [NEPolicyResult drop];
							NEPolicy *secundasPolicy = [[NEPolicy alloc] initWithOrder:501 result:secundasPolicyResult conditions:secundasPolicyConditions.copy];
							[policyIDs addObject:@([_policySession addPolicy:secundasPolicy])];
						}
					}
					
					//third order - in/outbounds
					if (tertiusRule != AKPDaemonTrafficRulePassAllBounds){
						NSMutableArray <NEPolicyCondition *> *tertiusPolicyConditions = [NSMutableArray array];
						[tertiusPolicyConditions addObject:[NEPolicyCondition effectiveApplication:uuid]];
						NEPolicyCondition *tertiusPolicyCondition = [NEPolicyCondition isInbound];
						tertiusPolicyCondition.negative = !(tertiusRule == AKPDaemonTrafficRuleDropOutbound);
						[tertiusPolicyConditions addObject:tertiusPolicyCondition];
						NEPolicyResult *tertiusPolicyResult = [NEPolicyResult drop];
						NEPolicy *tertiusPolicy = [[NEPolicy alloc] initWithOrder:502 result:tertiusPolicyResult conditions:tertiusPolicyConditions.copy];
						[policyIDs addObject:@([_policySession addPolicy:tertiusPolicy])];
					}
				}
				
				revokePrevPolicies();
				
				BOOL success = [_policySession apply];
				if (success && policyIDs.count > 0){
					_policies[uniqueIdentifier] = @{
						kPolicy : @(policy),
						kPolicyIDs : policyIDs.copy ?: @[],
						kPrimusDomains: domains ?: @[],
						kSecundasRule : @(secundasRule),
						kTertiusRule : @(tertiusRule),
						kMachOUUIDs : machOUUIDs?: @[]
					};
				}
				if (reply) reply(success, policyIDs.copy);
			}else{
				revokePrevPolicies();
				[_policySession apply];
				if (reply) reply(NO, nil);
			}
			break;
		}
			
#pragma mark AKPPolicingOrderGlobal
			
		case AKPPolicingOrderGlobal:
		default:{
			
			NSArray *globalRules = @[
				info[kPrimusRule] ?: @(AKPDaemonTrafficRulePassAllDomains),
				info[kSecundasRule] ?: @(AKPDaemonTrafficRulePassAllDomains)
			];
			
			NSArray *domains = @[
				info[kPrimusDomains] ?: @[],
				info[kSecundasDomains] ?: @[]
			];
			
			void (^revokePrevPolicies)() = ^{
				for (NSNumber *policyID in _policies[uniqueIdentifier][kPolicyIDs]){
					[_policySession removePolicyWithID:[policyID unsignedLongValue]];
				}
				[_policies removeObjectForKey:uniqueIdentifier];
			};
			
			for (NSUInteger rulesIdx = 0; rulesIdx <  globalRules.count; rulesIdx++){
				
				if ([globalRules[rulesIdx] intValue] != AKPDaemonTrafficRulePassAllDomains){
					
					for (NSString *rawDomain in domains[rulesIdx]){
						
						NSString *domain = rawDomain;
						
						NSArray *explodedDomain = [[self sanitizeDomainString:rawDomain] componentsSeparatedByString:@" "];
						if (explodedDomain.count > 1){ //127.0.0.1 apple.com
							domain = explodedDomain[1];
						}
						
						if (domain.length <= 0) continue;
						
						NSMutableArray <NEPolicyCondition *> *policyConditions = [NSMutableArray array];
						NEPolicyCondition *policyCondition = [NEPolicyCondition domain:domain];
						policyCondition.negative = !([globalRules[rulesIdx] intValue] == AKPDaemonTrafficRuleDropDomain);
						[policyConditions addObject:policyCondition];
						NEPolicyResult *policyResult = [NEPolicyResult drop];
						NEPolicy *policy = [[NEPolicy alloc] initWithOrder:100+rulesIdx result:policyResult conditions:policyConditions.copy];
						[policyIDs addObject:@([_policySession addPolicy:policy])];
					}
				}
			}
			
			revokePrevPolicies();
			
			BOOL success = [_policySession apply];
			if (success && policyIDs.count > 0){
				_policies[uniqueIdentifier] = @{
					kPolicyIDs : policyIDs.copy ?: @[],
					kPrimusDomains : domains[0],
					kSecundasDomains : domains[1],
					kPrimusRule : globalRules[0],
					kSecundasRule : globalRules[1]
				};
			}
			if (reply) reply(success, policyIDs.copy);
			
			break;
		}
	}
}

-(void)readPolicyWithInfo:(NSData *)data reply:(void (^)(AKPPolicyType))reply{
	NSDictionary *info = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	NSString *uniqueIdentifier = [self uniqueIdentifier:info];
	if (reply) reply([_policies[uniqueIdentifier][kPolicy] ?: @(AKPPolicyTypeAllAllow) intValue]);
}

-(void)currentPoliciesWithReply:(void (^)(NSData *policies))reply{
	if (reply) reply([NSKeyedArchiver archivedDataWithRootObject:_policies]);
}

@end
