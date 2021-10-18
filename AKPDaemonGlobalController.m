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
		_cancelled = YES;
		_editedDomains = [NSMutableDictionary dictionary];
		_editButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(edit)];
		_applyButton = [[UIBarButtonItem alloc] initWithTitle:@"Apply" style:UIBarButtonItemStylePlain target:self action:@selector(apply)];
		_cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
		self.navigationItem.rightBarButtonItems = @[_editButton];
		
		[self fetchLatestPoliciesAndReload:YES];
	}
	return self;
}

-(NSDictionary *)info{
	return [self.specifier propertyForKey:@"info"];
}

-(NSString *)uniqueIdentifier{
	return kGlobal;
}

-(void)fetchLatestPoliciesAndReload:(BOOL)reload{
	[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
		_policies = policies;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (reload) [self reloadSpecifiers];
		});
	}];
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
	
	__weak typeof(self) weakSelf = self;
	[self setDroplistValueWithCompletion:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf reloadDropListTextViews];
		});
	}];
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

-(void)setCacheValue:(id)value forSubkey:(NSString *)subkey{
	[AKPUtilities setDaemonCacheValue:value forSubkey:[self subkeyNameForComponent:subkey]];
}

-(void)setTamingValue:(id)value forKey:(NSString *)key{
	[AKPUtilities setDaemonTamingValue:value forKey:key];
}

-(id)readCacheValueForSubkey:(NSString *)subkey defaultValue:(id)defaultValue{
	return [AKPUtilities valueForDaemonCacheSubkey:[self subkeyNameForComponent:subkey] defaultValue:defaultValue];
}

-(NSString *)subkeyNameForComponent:(NSString *)componentName{
	return [NSString stringWithFormat:@"%@+%@", [self uniqueIdentifier], componentName];
}

-(void)setDomainsTrafficRule:(id)value specifier:(PSSpecifier *)specifier{
	if (value){
		NSString *ruleKey = [NSString stringWithFormat:@"%@_%@", [specifier propertyForKey:kPriority], kRule];
		
		NSString *primusDomainsKey = [NSString stringWithFormat:@"%@_%@", kPriorityPrimus, kDomains];
		NSString *secundasDomainsKey = [NSString stringWithFormat:@"%@_%@", kPrioritySecundas, kDomains];
		
		NSMutableArray *primusDomainsAsArray = [[self readDropListValue:_primusDroplistSpec] componentsSeparatedByString:@"\n"].mutableCopy;
		[primusDomainsAsArray removeObject:@""];
		
		NSMutableArray *secundasDomainsAsArray = [[self readDropListValue:_secundasDroplistSpec] componentsSeparatedByString:@"\n"].mutableCopy;
		[secundasDomainsAsArray removeObject:@""];
		
		[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
			NSMutableDictionary *policy = [policies[[self uniqueIdentifier]] ?: @{} mutableCopy];
			
			NSDictionary *newParams = @{
				kPolicingOrder : @(AKPPolicingOrderGlobal),
				kLabel : [self uniqueIdentifier],
				ruleKey : value,
				primusDomainsKey : primusDomainsAsArray.copy ?: @[],
				secundasDomainsKey : secundasDomainsAsArray.copy ?: @[]
			};
			[policy addEntriesFromDictionary:newParams];
			
			
			NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
			
			[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
				[self fetchLatestPoliciesAndReload:NO];
				if (!error){
					[self setTamingValue:cleansedPolicy forKey:[self uniqueIdentifier]];
				}
			}];
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
	
	[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
		NSMutableDictionary *policy = [policies[[self uniqueIdentifier]] ?: @{} mutableCopy];
		
		NSDictionary *newParams = @{
			kPolicingOrder : @(AKPPolicingOrderGlobal),
			kLabel : [self uniqueIdentifier],
			primusDomainsKey : primusDomainsAsArray.copy ?: @[],
			secundasDomainsKey : secundasDomainsAsArray ?: @[]
		};
		[policy addEntriesFromDictionary:newParams];
		
		NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
		
		[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
			[self fetchLatestPoliciesAndReload:NO];
			if (!error){
				[self setTamingValue:cleansedPolicy forKey:[self uniqueIdentifier]];
				[self setCacheValue:primusDomainsAsArray forSubkey:primusDomainsKey];
				[self setCacheValue:secundasDomainsAsArray forSubkey:secundasDomainsKey];
			}
			if (completionHandler) completionHandler();
		}];
	}];
}

-(id)readDropListValue:(PSSpecifier *)specifier{
	NSString *domainsKey = [NSString stringWithFormat:@"%@_%@", [specifier propertyForKey:kPriority], kDomains];
	
	if (!_cancelled && [_editedDomains[domainsKey] length] > 0){
		return _editedDomains[domainsKey];
	}else if (!_cancelled || [_policies[[self uniqueIdentifier]][domainsKey] count] > 0){
		return [_policies[[self uniqueIdentifier]][domainsKey] componentsJoinedByString:@"\n"];
	}else{
		return [[self readCacheValueForSubkey:domainsKey defaultValue:nil] componentsJoinedByString:@"\n"];
	}
}

-(void)setPendingDroplistValue:(id)value specifier:(PSSpecifier *)specifier{
	NSString *domainsKey = [NSString stringWithFormat:@"%@_%@", [specifier propertyForKey:kPriority], kDomains];
	_editedDomains[domainsKey] = value ?: @"";
}

@end
