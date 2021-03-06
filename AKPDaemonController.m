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

#import "AKPDaemonController.h"
#import "AKPDaemonListController.h"
#import "AKPUtilities.h"
#import "AKPNEUtilities.h"

@implementation AKPDaemonController

-(instancetype)init{
	if (self = [super init]){
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadAll) name:CLIUpdatedPrefsNotification object:nil];
		
		_policies = [NSMutableDictionary dictionary];
		_cache = [NSMutableDictionary dictionary];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self fetchLatestPoliciesAndReload:YES];
		});
	}
	return self;
}

-(NSDictionary *)info{
	return [self.specifier propertyForKey:@"info"];
}

-(void)updateLastDomains{
	NSArray *domains = _policies[[self uniqueIdentifier]][kPrimusDomains];
	if (domains.count > 0 && [_policies[[self uniqueIdentifier]][kSecundasRule] intValue] != AKPDaemonTrafficRulePassAllDomains){
		self.lastDomains = domains;
		self.isDomainsCache = NO;
	}else{
		self.lastDomains = [self readCacheValueForSubkey:kPrimusDomains defaultValue:nil];
		self.isDomainsCache = YES;
	}
}

-(void)updatePoliciesWithEntry:(NSDictionary *)policy forKey:(NSString *)key{
	if (_policies) _policies[key] = policy;
}

-(void)updateCacheWithEntry:(id)cacheValue forSubkey:(NSString *)subkey{
	if (_cache) _cache[[self subkeyNameForComponent:subkey]] = cacheValue;
}

-(void)reloadAll{
	[self fetchLatestPoliciesAndReload:YES];
}

-(void)fetchLatestPoliciesAndReload:(BOOL)reload{
	_prefs = [AKPUtilities prefs];
	_policies = [_prefs[kDaemonTamingKey] ?: @{} mutableCopy];
	_cache = [_prefs[kDaemonCacheKey] ?: @{} mutableCopy];
	[self updateLastDomains];
	dispatch_async(dispatch_get_main_queue(), ^{
		if (reload) [self reloadSpecifiers];
	});
}

-(NSArray *)specifiers{
	if (!_specifiers) {
		NSMutableArray *rootSpecifiers = [[NSMutableArray alloc] init];
		
		//wireless data section
		PSSpecifier *connectivityGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Connectivity" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:connectivityGroupSpec];
		
		//Wireless Data
		_wirelessDataSpec = [PSSpecifier preferenceSpecifierNamed:@"Wireless Data" target:self set:@selector(setWirelessDataPolicy:specifier:) get:@selector(readWirelessDataPolicy:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
		[_wirelessDataSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
		NSArray *policyValues = @[@(AKPPolicyTypeNone), @(AKPPolicyTypeLocalNetworkAllow), @(AKPPolicyTypeCellularAllow), @(AKPPolicyTypeWiFiAllow), @(AKPPolicyTypeAllAllow)];
		NSMutableArray *policyTitles = [NSMutableArray array];
		for (NSNumber *v in policyValues){
			[policyTitles addObject:[AKPUtilities stringForPolicy:[v intValue]]];
		}
		[_wirelessDataSpec setValues:policyValues titles:policyTitles];
		[rootSpecifiers addObject:_wirelessDataSpec];
		
		//Traffic section
		PSSpecifier *trafficGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Traffic" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:trafficGroupSpec];
		
		//Domains
		_trafficDomainsSpec = [PSSpecifier preferenceSpecifierNamed:@"Domains" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[_trafficDomainsSpec setProperty:NSClassFromString(@"AKPDaemonDomainsCell") forKey:@"cellClass"];
		[_trafficDomainsSpec setProperty:@"Domains" forKey:@"label"];
		[_trafficDomainsSpec setButtonAction:@selector(editDomains)];
		[rootSpecifiers addObject:_trafficDomainsSpec];
		
		//drop or pass domains traffic
		PSSpecifier *dropDomainsTrafficSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Rule" target:self set:@selector(setDomainsTrafficRule:specifier:) get:@selector(readDomainsTrafficRule:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
		[dropDomainsTrafficSelectionSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
		NSArray *ruleValues = @[@(AKPDaemonTrafficRulePassAllDomains), @(AKPDaemonTrafficRuleDropDomain), @(AKPDaemonTrafficRulePassDomain)];
		NSMutableArray *ruleTitles = [NSMutableArray array];
		for (NSNumber *v in ruleValues){
			[ruleTitles addObject:[AKPNEUtilities stringForTrafficRule:[v intValue] simple:NO]];
		}
		[dropDomainsTrafficSelectionSpec setValues:ruleValues titles:ruleTitles];
		[rootSpecifiers addObject:dropDomainsTrafficSelectionSpec];
		
		//drop or pass in/outbound traffic
		PSSpecifier *dropBoundingTrafficSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Direction (BETA)" target:self set:@selector(setBoundingTrafficRule:specifier:) get:@selector(readBoundingTrafficRule:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
		[dropBoundingTrafficSelectionSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
		NSArray *boundingValues = @[@(AKPDaemonTrafficRulePassAllBounds), @(AKPDaemonTrafficRuleDropOutbound), @(AKPDaemonTrafficRuleDropInbound)];
		NSMutableArray *boundingTitles = [NSMutableArray array];
		for (NSNumber *v in boundingValues){
			[boundingTitles addObject:[AKPNEUtilities stringForTrafficRule:[v intValue] simple:NO]];
		}
		[dropBoundingTrafficSelectionSpec setValues:boundingValues titles:boundingTitles];
		[rootSpecifiers addObject:dropBoundingTrafficSelectionSpec];
		
		_specifiers = rootSpecifiers;
	}
	return _specifiers;
}

-(void)reloadGranparentSpecifier:(PSSpecifier *)specifier{
	AKPDaemonController *parentController = (AKPDaemonController *)(specifier.target);
	AKPDaemonListController *grandparentController = (AKPDaemonListController *)(parentController.specifier.target);
	if ([grandparentController respondsToSelector:@selector(reloadSpecifierByInfo:animated:)]){
		grandparentController.policies = _policies;
		[grandparentController reloadSpecifierByInfo:[self info] animated:NO];
	}
}

-(void)setCacheValue:(id)value forSubkey:(NSString *)subkey{
	[AKPUtilities setDaemonCacheValue:value forSubkey:[self subkeyNameForComponent:subkey]];
}

-(void)setTamingValue:(id)value forKey:(NSString *)key{
	[AKPUtilities setDaemonTamingValue:value forKey:key];
}

-(id)readCacheValueForSubkey:(NSString *)subkey defaultValue:(id)defaultValue{
	return _cache[[self subkeyNameForComponent:subkey]] ?: defaultValue;
}

-(NSString *)subkeyNameForComponent:(NSString *)componentName{
	return [NSString stringWithFormat:@"%@+%@", [self uniqueIdentifier], componentName];
}

-(NSString *)uniqueIdentifier{
	NSDictionary *info = [self info];
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

-(void)setWirelessDataPolicy:(id)value specifier:(PSSpecifier *)specifier{
	if (value){
		NSMutableDictionary *policy = [_policies[[self uniqueIdentifier]] ?: @{} mutableCopy];
		
		NSDictionary *info = [self info];
		NSDictionary *newParams = @{
			kPolicingOrder : @(AKPPolicingOrderDaemon),
			kLabel : info[kLabel] ?: @"",
			kBundleID : info[kBundleID] ?: @"",
			kPath : info[kPath] ?: @"",
			kPolicy : value
		};
		[policy addEntriesFromDictionary:newParams];
		NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
		
		[self updatePoliciesWithEntry:cleansedPolicy forKey:[self uniqueIdentifier]];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[self setTamingValue:cleansedPolicy forKey:[self uniqueIdentifier]];
		});
		
		[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
			dispatch_async(dispatch_get_main_queue(), ^{
				[self reloadGranparentSpecifier:specifier];
			});
		}];
	}
}

-(id)readWirelessDataPolicy:(PSSpecifier *)specifier{
	return _policies[[self uniqueIdentifier]][kPolicy] ?: @(AKPPolicyTypeAllAllow);
}

-(void)setDomainsTrafficRule:(id)value specifier:(PSSpecifier *)specifier{
	if (value){
		
		if ([value intValue] != AKPDaemonTrafficRulePassAllDomains && self.lastDomains.count <= 0){
			UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Attention" message:@"Apply traffic rule with empty domain is not allowed." preferredStyle:UIAlertControllerStyleAlert];
			[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
				[self.navigationController popViewControllerAnimated:YES];
			}]];
			[self presentViewController:alert animated:YES completion:nil];
			return;
		}
		
		NSMutableDictionary *policy = [_policies[[self uniqueIdentifier]] ?: @{} mutableCopy];
		
		NSDictionary *info = [self info];
		NSDictionary *newParams = @{
			kPolicingOrder : @(AKPPolicingOrderDaemon),
			kLabel : info[kLabel] ?: @"",
			kBundleID : info[kBundleID] ?: @"",
			kPath : info[kPath] ?: @"",
			kSecundasRule : value,
			kPrimusDomains : (self.lastDomains.count > MAX_DAEMON_HOSTS_LIMIT && MAX_DAEMON_HOSTS_LIMIT > 0) ? [self.lastDomains subarrayWithRange:NSMakeRange(0, MAX_DAEMON_HOSTS_LIMIT - 1)] : (self.lastDomains ?: @[])
		};
		[policy addEntriesFromDictionary:newParams];
		NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
		
		[self updatePoliciesWithEntry:cleansedPolicy forKey:[self uniqueIdentifier]];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[self setTamingValue:cleansedPolicy forKey:[self uniqueIdentifier]];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self reloadGranparentSpecifier:specifier];
				[self updateLastDomains];
				[self reloadSpecifier:_trafficDomainsSpec animated:YES];
			});
		});
		
		[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
		}];
	}
}

-(id)readDomainsTrafficRule:(PSSpecifier *)specifier{
	return _policies[[self uniqueIdentifier]][kSecundasRule] ?: @(AKPDaemonTrafficRulePassAllDomains);
}

-(void)setBoundingTrafficRule:(id)value specifier:(PSSpecifier *)specifier{
	if (value){
		
		if ([value intValue] != AKPDaemonTrafficRulePassAllBounds && self.lastDomains.count <= 0){
			UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Attention" message:@"Applying traffic direction with empty domain is not allowed." preferredStyle:UIAlertControllerStyleAlert];
			[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
				[self.navigationController popViewControllerAnimated:YES];
			}]];
			[self presentViewController:alert animated:YES completion:nil];
			return;
		}
		
		NSMutableDictionary *policy = [_policies[[self uniqueIdentifier]] ?: @{} mutableCopy];
		
		NSDictionary *info = [self info];
		NSDictionary *newParams = @{
			kPolicingOrder : @(AKPPolicingOrderDaemon),
			kLabel : info[kLabel] ?: @"",
			kBundleID : info[kBundleID] ?: @"",
			kPath : info[kPath] ?: @"",
			kTertiusRule : value,
			kPrimusDomains : (self.lastDomains.count > MAX_DAEMON_HOSTS_LIMIT && MAX_DAEMON_HOSTS_LIMIT > 0) ? [self.lastDomains subarrayWithRange:NSMakeRange(0, MAX_DAEMON_HOSTS_LIMIT - 1)] : (self.lastDomains ?: @[])
		};
		[policy addEntriesFromDictionary:newParams];
		NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
		
		[self updatePoliciesWithEntry:cleansedPolicy forKey:[self uniqueIdentifier]];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[self setTamingValue:cleansedPolicy forKey:[self uniqueIdentifier]];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self reloadGranparentSpecifier:specifier];
				[self updateLastDomains];
				[self reloadSpecifier:_trafficDomainsSpec animated:YES];
			});
		});
		
		[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
		}];
	}
}

-(id)readBoundingTrafficRule:(PSSpecifier *)specifier{
	return _policies[[self uniqueIdentifier]][kTertiusRule] ?: @(AKPDaemonTrafficRulePassAllBounds);
}

-(void)editDomains{
	__weak typeof(self) weakSelf = self;
	[self addDomainsAndSave:YES withResult:^(NSArray <NSString *>*domains){
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf reloadSpecifiers];
		});
	} onError:^(NSError *error, NSArray <NSString *> *domains){
		dispatch_async(dispatch_get_main_queue(), ^{
			if (error){
				[weakSelf popErrorAlert:error onOk:^{
					[weakSelf reloadSpecifiers];
				}];
			}else{
				[weakSelf reloadSpecifiers];
			}
		});
	}];
}

-(void)popDelayedApplyAlertIfNecessary{
	if (![_prefs[kAcknowledgedDelayedApplyKey] ?: @NO boolValue]){
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Attention" message:delayedApplyMessage preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"Remind Again" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
		}]];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
			[AKPUtilities setValue:@YES forKey:kAcknowledgedDelayedApplyKey];
		}]];
		[self presentViewController:alert animated:YES completion:nil];
	}
}

-(void)addDomainsAndSave:(BOOL)save withResult:(void (^)(NSArray <NSString *>*))result onError:(void(^)(NSError *, NSArray <NSString *>*))errorHandler{
	[self popTextViewWithTitle:@"Domains" message:@"Each domain separated by new line.\n\n\n\n\n" text:[(self.lastDomains ?: [self readCacheValueForSubkey:kPrimusDomains defaultValue:nil]) componentsJoinedByString:@"\n"] onDone:^(NSArray <NSString *> *domains){
		[self popDelayedApplyAlertIfNecessary];
		if (save){
			NSMutableDictionary *policy = [_policies[[self uniqueIdentifier]] ?: @{} mutableCopy];
			
			NSDictionary *info = [self info];
			NSDictionary *newParams = @{
				kPolicingOrder : @(AKPPolicingOrderDaemon),
				kLabel : info[kLabel] ?: @"",
				kBundleID : info[kBundleID] ?: @"",
				kPath : info[kPath] ?: @"",
				kPrimusDomains : (domains.count > MAX_DAEMON_HOSTS_LIMIT && MAX_DAEMON_HOSTS_LIMIT > 0) ? [domains subarrayWithRange:NSMakeRange(0, MAX_DAEMON_HOSTS_LIMIT - 1)] : (domains ?: @[])
			};
			[policy addEntriesFromDictionary:newParams];
			NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
			
			[self updatePoliciesWithEntry:cleansedPolicy forKey:[self uniqueIdentifier]];
			[self updateCacheWithEntry:domains forSubkey:kPrimusDomains];
			
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				[self setTamingValue:cleansedPolicy forKey:[self uniqueIdentifier]];
				[self setCacheValue:domains forSubkey:kPrimusDomains];
			});
			
			self.lastDomains = domains;
			
			[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
				if (result) result(domains);
			}];
		}else{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				[self setCacheValue:domains forSubkey:kPrimusDomains];
			});
			[self updateCacheWithEntry:domains forSubkey:kPrimusDomains];
			self.lastDomains = domains;
			if (result) result(domains);
		}
	} onCancel:^(id ret){
		if (result) result(ret);
	}];
}

-(void)popTextViewWithTitle:(NSString *)title message:(NSString *)message text:(NSString *)text onDone:(void(^)(id))doneHandler onCancel:(void(^)(id))cancelHandler{
	
	__block NSMutableArray <NSString *> *input;
	
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
	alert.view.autoresizesSubviews = YES;
	
	UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
	textView.autocorrectionType = UITextAutocorrectionTypeNo;
	textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
	
	textView.text = text;
	
	textView.translatesAutoresizingMaskIntoConstraints = NO;
	
	NSLayoutConstraint *leadConstraint = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:textView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:-8.0];
	NSLayoutConstraint *trailConstraint = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:textView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:8.0];
	
	NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:textView attribute:NSLayoutAttributeTop multiplier:1.0 constant:-64.0];
	NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:textView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:64.0];
	[alert.view addSubview:textView];
	[NSLayoutConstraint activateConstraints:@[leadConstraint, trailConstraint, topConstraint, bottomConstraint]];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
		input = [textView.text componentsSeparatedByString:@"\n"].mutableCopy;
		[input removeObject:@""];
		if (doneHandler) doneHandler(input);
	}]];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
		if (cancelHandler) cancelHandler(nil);
	}]];
	
	[self presentViewController:alert animated:YES completion:nil];
}

-(void)popErrorAlert:(NSError *)error onOk:(void (^)())okHandler{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Error: %ld", error.code] message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
		okHandler();
	}];
	[alert addAction:okAction];
	[self presentViewController:alert animated:YES completion:nil];
}
@end
