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

#import "AKPDaemonApplicationListSubcontrollerController.h"
#import "AKPUtilities.h"
#import "AKPNEUtilities.h"
#import <AltList/LSApplicationProxy+AltList.h>

@implementation AKPDaemonApplicationListSubcontrollerController
-(instancetype)init{
	if (self = [super init]){
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSpecifiers) name:CLIUpdatedPrefsNotification object:nil];
		
		self.policies = [AKPUtilities valueForKey:kDaemonTamingKey defaultValue:nil];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self reloadSpecifiers];
		});
	}
	return self;
}

-(PSSpecifier *)createSpecifierForApplicationProxy:(LSApplicationProxy *)applicationProxy{
	PSSpecifier *spec = [super createSpecifierForApplicationProxy:applicationProxy];
	NSDictionary *info = @{
		kBundleID : applicationProxy.bundleIdentifier
	};
	[spec setProperty:info forKey:@"info"];
	return spec;
}

-(PSSpecifier *)specifierByInfo:(NSDictionary *)info{
	for (PSSpecifier *spec in _specifiers){
		if ([[spec propertyForKey:@"info"][kBundleID] isEqualToString:info[kBundleID]]){
			return spec;
		}
	}
	return nil;
}

-(void)reloadSpecifierByInfo:(NSDictionary *)info animated:(BOOL)animated{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self reloadSpecifier:[self specifierByInfo:info] animated:animated];
	});
}

-(NSString*)subtitleForApplicationWithIdentifier:(NSString*)applicationID{
	AKPPolicyType policy = [self.policies[applicationID][kPolicy] ?: @(AKPPolicyTypeAllAllow) intValue];
	return [AKPUtilities stringForPolicy:policy];
}

- (NSString*)previewStringForApplicationWithIdentifier:(NSString *)applicationID{
	NSMutableArray *previewsArray = [NSMutableArray array];
	
	AKPPolicyType policy = [self.policies[applicationID][kPolicy] ?: @(AKPPolicyTypeAllAllow) intValue];
	if (policy != AKPPolicyTypeAllAllow){
		[previewsArray addObject:[AKPUtilities stringForPolicy:policy]];
	}
	
	AKPDaemonTrafficRule trafficRule = [self.policies[applicationID][kSecundasRule] ?: @(AKPDaemonTrafficRulePassAllDomains) intValue];
	if (trafficRule != AKPDaemonTrafficRulePassAllDomains){
		[previewsArray addObject:[AKPNEUtilities stringForTrafficRule:trafficRule simple:YES]];
	}
	
	return [previewsArray componentsJoinedByString:@" | "];
}

@end
