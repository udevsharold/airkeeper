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
#import <libproc/libproc_internal.h>

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
		
		_lock = OS_UNFAIR_LOCK_INIT;
		_requestCount = [NSMutableDictionary dictionary];
		
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
		
		
	}
	return self;
}

-(void)terminateIfNecessary{
	
	if (_processing > 0){
		[self queueTerminationIfNecessaryWithDelay:120];
		return;
	};
	
	if (_policySession.policies.allKeys.count > 0) return;
	
	[[NSFileManager defaultManager] removeItemAtPath:KEEP_ALIVE_FILE error:nil];
	exit(EXIT_SUCCESS);
}

-(void)queueTerminationIfNecessaryWithDelay:(int64_t)delay{
	self.initialized = YES;
	if (_terminationVerificationBlock) dispatch_block_cancel(_terminationVerificationBlock);
	_terminationVerificationBlock = dispatch_block_create(static_cast<dispatch_block_flags_t>(0), ^{
		[self terminateIfNecessary];
		_terminationVerificationBlock = nil;
	});
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), _terminationVerificationBlock);
}

-(void)handleAppInstalled:(NSString *)bundleID{
	HBLogDebug(@"handleAppInstalled: %@", bundleID);
	NSDictionary *tamingParams = [AKPUtilities valueForKey:kDaemonTamingKey defaultValue:nil];
	if (tamingParams[bundleID]){
		[self setPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:tamingParams[bundleID]] reply:^(NSError *error){
		}];
	}
}

-(void)handleAppUninstalled:(NSString *)bundleID{
	HBLogDebug(@"handleAppUninstalled: %@", bundleID);
	[self revokePoliciesForAccount:bundleID];
}

-(void)initializeSessionAndWait:(BOOL)wait reply:(void (^)(NSError *error))reply{
	
	[_policySession removeAllPolicies];
	[_policySession apply];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		NSDictionary *tamingParams = [AKPUtilities valueForKey:kDaemonTamingKey defaultValue:nil];
		if (tamingParams){
			NSArray *allKeys = tamingParams.allKeys;
			__block NSUInteger idx = 1;
			if (allKeys.count > 0){
				if (!wait && reply) reply(nil);
				for (NSString *key in allKeys){
					[self setPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:tamingParams[key]] reply:^(NSError *error){
						if (idx >= allKeys.count){
							if (wait && reply) reply(error);
						}
						idx++;
					}];
				}
			}else{
				if (reply) reply(nil);
			}
		}else{
			if (reply) reply(nil);
		}
	});
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

-(AKPPolicingOrder)policingOrder:(NSDictionary *)info{
	return [info[kPolicingOrder] ?: @(AKPPolicingOrderDaemon) intValue];
}

-(void)setPolicyWithInfoArray:(NSData *)data reply:(void (^)(NSError *error))reply{
	NSArray *infos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	__block NSUInteger completedIdx = 1;
	NSUInteger expectedOperations = infos.count;
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *info in infos){
		[weakSelf setPolicyWithInfo:[NSKeyedArchiver archivedDataWithRootObject:info] reply:^(NSError *error){
			if (completedIdx >= expectedOperations){
				if (reply) reply(error);
			}
			completedIdx++;
		}];
	}
}

-(void)revokePoliciesForAccount:(NSString *)accountIdentifier{
	NSArray *filteredPolicyIDs;
	[AKPNEUtilities policies:nil ids:&filteredPolicyIDs accountIdentifier:accountIdentifier from:_policySession.policies];
	for (NSNumber *policyID in filteredPolicyIDs){
		[_policySession removePolicyWithID:[policyID unsignedLongValue]];
		[_policySession apply];
	}
}

-(void)setPolicyWithInfo:(NSData *)data wait:(BOOL)wait reply:(void (^)(NSError *error))reply{
	NSDictionary *info = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	// path > bundle_id > label
	NSString *uniqueIdentifier = [self uniqueIdentifier:info];
	if (uniqueIdentifier.length <= 0){
		if (reply) reply(AKPERROR(AKP_ERR_INVALID_ID, @"Invalid identifier."));
		return;
	}
	
	BOOL sameAccount = [uniqueIdentifier isEqualToString:_processingAccount];
	
	if (sameAccount || !_processingAccount){
		_stopTask = YES;
		HBLogDebug(@"Stopping task: %@", uniqueIdentifier);
	}
	
	AKPPolicingOrder policingOrder = [self policingOrder:info];
	
	_requestCount[uniqueIdentifier] = @([_requestCount[uniqueIdentifier] ?: @0 intValue] + 1);
	
	os_unfair_lock_lock(&_lock);
	HBLogDebug(@"processing: %@", uniqueIdentifier);
	
	_stopTask = NO;
	
	if (!wait){
		if (reply) reply(nil);
	}
	
	_processing++;
	_processingAccount = uniqueIdentifier;
	
	//only process the last request
	if ([_requestCount[uniqueIdentifier] intValue] > 1){
		if (reply) reply(nil);
		goto finish;
	}
	
	switch (policingOrder) {
			
#pragma mark AKPPolicingOrderDaemon
			
		case AKPPolicingOrderDaemon:{
			
			
			[self revokePoliciesForAccount:uniqueIdentifier];
			
			AKPDaemonTrafficRule secundasRule = [info[kSecundasRule] ?: @(AKPDaemonTrafficRulePassAllDomains) intValue];
			AKPDaemonTrafficRule tertiusRule = [info[kTertiusRule] ?: @(AKPDaemonTrafficRulePassAllBounds) intValue];
			
			NSArray *domains = info[kPrimusDomains] ?: @[];
			NSArray *machOUUIDs = [self machOUUIDs:info];
			
			AKPPolicyType policy = [info[kPolicy] ?: @(AKPPolicyTypeAllAllow) intValue];
			
			if (machOUUIDs){
				
				//primus
				NEPolicy *primusPolicy = [[NEPolicy alloc] initWithOrder:500 result:[NEPolicyResult routeRules:[AKPNEUtilities policyAsRouteRules:policy]] conditions:@[]];
				
				//secundas
				NEPolicy *secundasPolicy = [[NEPolicy alloc] initWithOrder:501 result:[NEPolicyResult drop] conditions:@[]];
				NEPolicyCondition *secundasPolicyCondition = [NEPolicyCondition domain:@"airkeeper.dummy"];
				secundasPolicyCondition.accountIdentifier = uniqueIdentifier;
				secundasPolicyCondition.negative = !(secundasRule == AKPDaemonTrafficRuleDropDomain);
				
				//tertius
				NEPolicy *tertiusPolicy = [[NEPolicy alloc] initWithOrder:502 result:[NEPolicyResult drop] conditions:@[]];
				NEPolicyCondition *tertiusPolicyCondition = [NEPolicyCondition isInbound];
				tertiusPolicyCondition.accountIdentifier = uniqueIdentifier;
				tertiusPolicyCondition.negative = !(tertiusRule == AKPDaemonTrafficRuleDropOutbound);
				
				//compulsory condition for all rules
				NEPolicyCondition *effectivePolicyCondition;
				
				for (NSUUID *uuid in machOUUIDs){
					
					if (_stopTask) break;
					
					effectivePolicyCondition = [NEPolicyCondition effectiveApplication:uuid];
					effectivePolicyCondition.accountIdentifier = uniqueIdentifier;
					
					//first order - net connectivity
					if (policy != AKPPolicyTypeAllAllow){
						primusPolicy.conditions = @[effectivePolicyCondition];
						[_policySession addPolicy:primusPolicy];
						[_policySession apply];
					}
					
					//second order - domains
					NSUInteger domainsAddedCount = 1;
					
					if (secundasRule != AKPDaemonTrafficRulePassAllDomains){
						
						NSArray *explodedDomain;
						NSString *domain;
						
						for (NSString *rawDomain in domains){
							
							if (_stopTask) break;
							
							domain = [rawDomain stringByReplacingOccurrencesOfString:@"^\\s+|\\s+$|\\s+(?=\\s)" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, rawDomain.length)];
							
							if ([domain hasPrefix:@"#"]) continue;
							
							explodedDomain = [domain componentsSeparatedByString:@" "];
							if (explodedDomain.count > 1){ //127.0.0.1 apple.com
								domain = explodedDomain[1];
							}
							
							if (domain.length <= 0) continue;
							if (MAX_DAEMON_HOSTS_LIMIT > 0 && domainsAddedCount > MAX_DAEMON_HOSTS_LIMIT) break;
							
							secundasPolicyCondition.domain = domain;
							secundasPolicy.conditions = @[effectivePolicyCondition, secundasPolicyCondition];
							[_policySession addPolicy:secundasPolicy];
							[_policySession apply];
							domainsAddedCount++;
						}
					}
					
					//third order - in/outbounds
					if (tertiusRule != AKPDaemonTrafficRulePassAllBounds){
						tertiusPolicy.conditions = @[effectivePolicyCondition, tertiusPolicyCondition];
						[_policySession addPolicy:tertiusPolicy];
						[_policySession apply];
					}
					
				}
				if (reply) reply(nil);
			}else{
				if (reply) reply(nil);
			}
			
			break;
		}
			
#pragma mark AKPPolicingOrderGlobal
			
		case AKPPolicingOrderGlobal:
		default:{
			
			[self revokePoliciesForAccount:uniqueIdentifier];
			
			NSArray *globalRules = @[
				info[kPrimusRule] ?: @(AKPDaemonTrafficRulePassAllDomains),
				info[kSecundasRule] ?: @(AKPDaemonTrafficRulePassAllDomains)
			];
			
			NSArray *domains = @[
				info[kPrimusDomains] ?: @[],
				info[kSecundasDomains] ?: @[]
			];
			
			
			NEPolicyCondition *policyCondition = [NEPolicyCondition domain:@"airkeeper.dummy"];
			policyCondition.accountIdentifier = uniqueIdentifier;
			NEPolicy *policy = [[NEPolicy alloc] initWithOrder:100 result:[NEPolicyResult drop] conditions:@[]];
			policy.result = [NEPolicyResult drop];
			
			//Total primus & secundas
			NSUInteger domainsAddedCount = 1;
			
			for (NSUInteger rulesIdx = 0; rulesIdx <  globalRules.count; rulesIdx++){
				
				if (_stopTask) break;
				
				policy.order = 100+rulesIdx;
				
				if ([globalRules[rulesIdx] intValue] != AKPDaemonTrafficRulePassAllDomains){
					
					policyCondition.negative = !([globalRules[rulesIdx] intValue] == AKPDaemonTrafficRuleDropDomain);
					
					NSArray *explodedDomain;
					NSString *domain;
					
					for (NSString *rawDomain in domains[rulesIdx]){
						
						if (_stopTask) break;
						
						domain = [rawDomain stringByReplacingOccurrencesOfString:@"^\\s+|\\s+$|\\s+(?=\\s)" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, rawDomain.length)];
						
						if ([domain hasPrefix:@"#"]) continue;
						
						explodedDomain = [domain componentsSeparatedByString:@" "];
						if (explodedDomain.count > 1){ //127.0.0.1 apple.com
							domain = explodedDomain[1];
						}
						
						if (domain.length <= 0) continue;
						if (MAX_GLOBAL_HOSTS_LIMIT > 0 && domainsAddedCount > MAX_GLOBAL_HOSTS_LIMIT) break;
						
						policyCondition.domain = domain;
						policy.conditions = @[policyCondition];
						//Must run serially
						[_policySession addPolicy:policy];
						[_policySession apply];
						domainsAddedCount++;
					}
					
				}
			}
			
			if (reply) reply(nil);
			break;
		}
	}
	
finish:
	_requestCount[uniqueIdentifier] = @([_requestCount[uniqueIdentifier] ?: @0 intValue] - 1);
	_processing--;
	_processingAccount = nil;
	os_unfair_lock_unlock(&_lock);
}

-(void)setPolicyWithInfo:(NSData *)data reply:(void (^)(NSError *error))reply{
	[self setPolicyWithInfo:data wait:YES reply:^(NSError *error){
		if (reply) reply(error);
	}];
}

@end
