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

#import "AKPDaemonGlobalController.h"
#import "AKPTextViewCell.h"
#import "AKPUtilities.h"
#import "AKPNEUtilities.h"

@implementation AKPDaemonGlobalController

-(instancetype)init{
	if (self = [super init]){
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadAll) name:CLIUpdatedPrefsNotification object:nil];
		
		_policies = [NSMutableDictionary dictionary];
		_cancelled = YES;
		_editedDomains = [NSMutableDictionary dictionary];
		_editButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(edit)];
		_applyButton = [[UIBarButtonItem alloc] initWithTitle:@"Apply" style:UIBarButtonItemStylePlain target:self action:@selector(apply)];
		_cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
		self.navigationItem.rightBarButtonItems = @[_editButton];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self fetchLatestPoliciesAndReload:YES];
		});
	}
	return self;
}

-(NSDictionary *)info{
	return [self.specifier propertyForKey:@"info"];
}

-(NSString *)uniqueIdentifier{
	return kGlobal;
}

-(void)updatePoliciesWithEntry:(NSDictionary *)policy forKey:(NSString *)key{
	_policies[key] = policy;
}

-(void)reloadAll{
	[self fetchLatestPoliciesAndReload:YES];
}

-(void)fetchLatestPoliciesAndReload:(BOOL)reload{
	_prefs = [AKPUtilities prefs];
	_policies = [_prefs[kDaemonTamingKey] ?: @{} mutableCopy];
	dispatch_async(dispatch_get_main_queue(), ^{
		if (reload) [self reloadSpecifiers];
	});
}

-(void)reloadDropListTextViews{
	[_primusDroplistSpec setProperty:@(_editing) forKey:@"editable"];
	[_secundasDroplistSpec setProperty:@(_editing) forKey:@"editable"];
	[_primusDropDomainsSpec setProperty:@(!_editing) forKey:@"enabled"];
	[_secundasDropDomainsSpec setProperty:@(!_editing) forKey:@"enabled"];
	[self reloadSpecifier:_primusDroplistSpec animated:YES];
	[self reloadSpecifier:_secundasDroplistSpec animated:YES];
	[self reloadSpecifier:_primusDropDomainsSpec animated:YES];
	[self reloadSpecifier:_secundasDropDomainsSpec animated:YES];
}

-(void)popDelayedApplyAlertIfNecessary{
	__weak typeof(self) weakSelf = self;
	if (![_prefs[kAcknowledgedDelayedApplyKey] ?: @NO boolValue]){
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Attention" message:delayedApplyMessage preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"Remind Again" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
			dispatch_async(dispatch_get_main_queue(), ^{
				[weakSelf reloadDropListTextViews];
			});
		}]];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
			[AKPUtilities setValue:@YES forKey:kAcknowledgedDelayedApplyKey];
			dispatch_async(dispatch_get_main_queue(), ^{
				[weakSelf reloadDropListTextViews];
			});
		}]];
		[self presentViewController:alert animated:YES completion:nil];
	}
}

-(void)edit{
	_editing = YES;
	_cancelled = YES;
	self.navigationItem.rightBarButtonItems = @[_applyButton, _cancelButton];
	[self reloadDropListTextViews];
}

-(void)apply{
	_editing = NO;
	_cancelled = NO;
	self.navigationItem.rightBarButtonItems = @[_editButton];
	
	[self popDelayedApplyAlertIfNecessary];
	
	[self setDroplistValueWithCompletion:^{
	}];
	[self reloadDropListTextViews];
}

-(void)cancel{
	_editing = NO;
	_cancelled = YES;
	self.navigationItem.rightBarButtonItems = @[_editButton];
	[self reloadDropListTextViews];
}

-(NSArray *)specifiers{
	if (!_specifiers){
		NSMutableArray *rootSpecifiers = [[NSMutableArray alloc] init];
		
		//drop section - PRIMUS
		PSSpecifier *primusGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Domains (PRIMARY)" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:primusGroupSpec];
		
		NSArray *ruleValues = @[@(AKPDaemonTrafficRulePassAllDomains), @(AKPDaemonTrafficRuleDropDomain), @(AKPDaemonTrafficRulePassDomain)];
		NSMutableArray *ruleTitles = [NSMutableArray array];
		for (NSNumber *v in ruleValues){
			[ruleTitles addObject:[AKPNEUtilities stringForTrafficRule:[v intValue] simple:NO]];
		}
		
		//drop or pass domains traffic
		_primusDropDomainsSpec = [PSSpecifier preferenceSpecifierNamed:@"Rule" target:self set:@selector(setDomainsTrafficRule:specifier:) get:@selector(readDomainsTrafficRule:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
		[_primusDropDomainsSpec setProperty:kPriorityPrimus forKey:kPriority];
		[_primusDropDomainsSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
		[_primusDropDomainsSpec setValues:ruleValues titles:ruleTitles];
		[_primusDropDomainsSpec setProperty:@(!_editing) forKey:@"enabled"];
		[rootSpecifiers addObject:_primusDropDomainsSpec];
		
		//Domains
		_primusDroplistSpec = [PSSpecifier preferenceSpecifierNamed:@"Domains" target:self set:@selector(setPendingDroplistValue:specifier:) get:@selector(readDropListValue:) detail:nil cell:PSDefaultCell edit:nil];
		[_primusDroplistSpec setProperty:kPriorityPrimus forKey:kPriority];
		[_primusDroplistSpec setProperty:NSClassFromString(@"AKPTextViewCell") forKey:@"cellClass"];
		[_primusDroplistSpec setProperty:@200 forKey:@"height"];
		[_primusDroplistSpec setProperty:@(_editing) forKey:@"editable"];
		[rootSpecifiers addObject:_primusDroplistSpec];
		
		
		//drop section - SECUNDAS
		PSSpecifier *secundasGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Domains (SECONDARY)" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:secundasGroupSpec];
		
		//drop or pass domains traffic
		_secundasDropDomainsSpec = [PSSpecifier preferenceSpecifierNamed:@"Rule" target:self set:@selector(setDomainsTrafficRule:specifier:) get:@selector(readDomainsTrafficRule:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
		[_secundasDropDomainsSpec setProperty:kPrioritySecundas forKey:kPriority];
		[_secundasDropDomainsSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
		[_secundasDropDomainsSpec setValues:ruleValues titles:ruleTitles];
		[_secundasDropDomainsSpec setProperty:@(!_editing) forKey:@"enabled"];
		[rootSpecifiers addObject:_secundasDropDomainsSpec];
		
		//Domains
		_secundasDroplistSpec = [PSSpecifier preferenceSpecifierNamed:@"Domains" target:self set:@selector(setPendingDroplistValue:specifier:) get:@selector(readDropListValue:) detail:nil cell:PSDefaultCell edit:nil];
		[_secundasDroplistSpec setProperty:kPrioritySecundas forKey:kPriority];
		[_secundasDroplistSpec setProperty:NSClassFromString(@"AKPTextViewCell") forKey:@"cellClass"];
		[_secundasDroplistSpec setProperty:@200 forKey:@"height"];
		[_secundasDroplistSpec setProperty:@(_editing) forKey:@"editable"];
		[rootSpecifiers addObject:_secundasDroplistSpec];
		
		_specifiers = rootSpecifiers;
	}
	return _specifiers;
}

-(void)setTamingValue:(id)value forKey:(NSString *)key{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		[AKPUtilities setDaemonTamingValue:value forKey:key];
	});
}

-(NSString *)subkeyNameForComponent:(NSString *)componentName{
	return [NSString stringWithFormat:@"%@+%@", [self uniqueIdentifier], componentName];
}

-(void)setDomainsTrafficRule:(id)value specifier:(PSSpecifier *)specifier{
	if (value){
		
		[self popDelayedApplyAlertIfNecessary];
		
		NSString *ruleKey = [NSString stringWithFormat:@"%@_%@", [specifier propertyForKey:kPriority], kRule];
		
		NSString *primusDomainsKey = [NSString stringWithFormat:@"%@_%@", kPriorityPrimus, kDomains];
		NSString *secundasDomainsKey = [NSString stringWithFormat:@"%@_%@", kPrioritySecundas, kDomains];
		
		NSMutableArray *primusDomainsAsArray = [[self readDropListValue:_primusDroplistSpec] componentsSeparatedByString:@"\n"].mutableCopy;
		[primusDomainsAsArray removeObject:@""];
		
		NSMutableArray *secundasDomainsAsArray = [[self readDropListValue:_secundasDroplistSpec] componentsSeparatedByString:@"\n"].mutableCopy;
		[secundasDomainsAsArray removeObject:@""];
		
		NSMutableDictionary *policy = [_policies[[self uniqueIdentifier]] ?: @{} mutableCopy];
		
		NSDictionary *newParams = @{
			kPolicingOrder : @(AKPPolicingOrderGlobal),
			kLabel : [self uniqueIdentifier],
			ruleKey : value,
			primusDomainsKey : (primusDomainsAsArray.count > MAX_GLOBAL_HOSTS_LIMIT && MAX_GLOBAL_HOSTS_LIMIT > 0) ? [primusDomainsAsArray subarrayWithRange:NSMakeRange(0, MAX_GLOBAL_HOSTS_LIMIT - 1)] : (primusDomainsAsArray ?: @[]),
			secundasDomainsKey : (secundasDomainsAsArray.count > MAX_GLOBAL_HOSTS_LIMIT && MAX_GLOBAL_HOSTS_LIMIT > 0) ? [secundasDomainsAsArray subarrayWithRange:NSMakeRange(0, MAX_GLOBAL_HOSTS_LIMIT - 1)] : (secundasDomainsAsArray ?: @[])
		};
		[policy addEntriesFromDictionary:newParams];
		
		NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
		
		[self updatePoliciesWithEntry:cleansedPolicy forKey:[self uniqueIdentifier]];
		
		[self setTamingValue:cleansedPolicy forKey:[self uniqueIdentifier]];
		
		[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
			if (!error){
			}
		}];
	}
}

-(id)readDomainsTrafficRule:(PSSpecifier *)specifier{
	NSString *ruleKey = [NSString stringWithFormat:@"%@_%@", [specifier propertyForKey:kPriority], kRule];
	return _policies[[self uniqueIdentifier]][ruleKey] ?: @(AKPDaemonTrafficRulePassAllDomains);
}

-(void)setDroplistValueWithCompletion:(void (^)())completionHandler{
	NSString *primusDomainsKey = [NSString stringWithFormat:@"%@_%@", kPriorityPrimus, kDomains];
	NSString *secundasDomainsKey = [NSString stringWithFormat:@"%@_%@", kPrioritySecundas, kDomains];
	
	NSMutableArray *primusDomainsAsArray = [[self readDropListValue:_primusDroplistSpec] componentsSeparatedByString:@"\n"].mutableCopy;
	[primusDomainsAsArray removeObject:@""];
	
	NSMutableArray *secundasDomainsAsArray = [[self readDropListValue:_secundasDroplistSpec] componentsSeparatedByString:@"\n"].mutableCopy;
	[secundasDomainsAsArray removeObject:@""];
	
	NSMutableDictionary *policy = [_policies[[self uniqueIdentifier]] ?: @{} mutableCopy];
	
	NSDictionary *newParams = @{
		kPolicingOrder : @(AKPPolicingOrderGlobal),
		kLabel : [self uniqueIdentifier],
		primusDomainsKey : (primusDomainsAsArray.count > MAX_GLOBAL_HOSTS_LIMIT && MAX_GLOBAL_HOSTS_LIMIT > 0) ? [primusDomainsAsArray subarrayWithRange:NSMakeRange(0, MAX_GLOBAL_HOSTS_LIMIT - 1)] : (primusDomainsAsArray ?: @[]),
		secundasDomainsKey : (secundasDomainsAsArray.count > MAX_GLOBAL_HOSTS_LIMIT && MAX_GLOBAL_HOSTS_LIMIT > 0) ? [secundasDomainsAsArray subarrayWithRange:NSMakeRange(0, MAX_GLOBAL_HOSTS_LIMIT - 1)] : (secundasDomainsAsArray ?: @[])
	};
	[policy addEntriesFromDictionary:newParams];
	
	NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
	[self updatePoliciesWithEntry:cleansedPolicy forKey:[self uniqueIdentifier]];
	
	[self setTamingValue:cleansedPolicy forKey:[self uniqueIdentifier]];
	[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
		if (completionHandler) completionHandler();
	}];
}

-(id)readDropListValue:(PSSpecifier *)specifier{
	NSString *domainsKey = [NSString stringWithFormat:@"%@_%@", [specifier propertyForKey:kPriority], kDomains];
	
	if (!_cancelled && [_editedDomains[domainsKey] length] > 0){
		return _editedDomains[domainsKey];
	}else if (!_cancelled || [_policies[[self uniqueIdentifier]][domainsKey] count] > 0){
		return [_policies[[self uniqueIdentifier]][domainsKey] componentsJoinedByString:@"\n"];
	}else{
		return nil;
	}
}

-(void)setPendingDroplistValue:(id)value specifier:(PSSpecifier *)specifier{
	NSString *domainsKey = [NSString stringWithFormat:@"%@_%@", [specifier propertyForKey:kPriority], kDomains];
	_editedDomains[domainsKey] = value ?: @"";
}

@end
