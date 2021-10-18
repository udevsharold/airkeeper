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

#import "AKPApplicationListSubcontrollerController.h"
#import "AKPUtilities.h"
#import <dlfcn.h>

@implementation AKPApplicationListSubcontrollerController
-(instancetype)init{
	if (self = [super init]){
		_ctConnection = [AKPUtilities ctConnection];
		_perAppVPNConfiguration = [AKPPerAppVPNConfiguration new];
	}
	return self;
}

-(void)reloadConfigurationsAndReloadSpecifier:(PSSpecifier *)specifier{
	[_perAppVPNConfiguration reloadConfigurations:^{
		[self reloadSpecifier:specifier animated:NO];
	}];
}

-(void)dealloc{
	if (_ctConnection) CFRelease(_ctConnection);
}

-(NSString*)subtitleForApplicationWithIdentifier:(NSString*)applicationID{
	return [AKPUtilities policyAsString:applicationID connection:_ctConnection success:nil];
}

- (NSString*)previewStringForApplicationWithIdentifier:(NSString *)applicationID{
	NSMutableArray *previewsArray = [NSMutableArray array];
	
	AKPPolicyType type = [AKPUtilities readPolicy:applicationID connection:_ctConnection success:nil];
	if (type != AKPPolicyTypeAllAllow){
		[previewsArray addObject:[AKPUtilities stringForPolicy:type]];
	}
	
	_perAppVPNConfiguration.bundleIdentifier = applicationID;
	NSArray <NEConfiguration *> *residingConfigurations = [_perAppVPNConfiguration residingConfigurationsForApp];
	if (residingConfigurations.count > 0){
		[previewsArray addObject:@"VPN"];
	}
	
	return [previewsArray componentsJoinedByString:@" | "];
}

-(void)viewDidLoad{
	[super viewDidLoad];
	PSSpecifier *acknowledgedRiskSpec = [PSSpecifier preferenceSpecifierNamed:@"Acknowledged Risk" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
	[acknowledgedRiskSpec setProperty:@"acknowledgedRisk" forKey:@"key"];
	[acknowledgedRiskSpec setProperty:nil forKey:@"default"];
	[acknowledgedRiskSpec setProperty:PREFS_CHANGED_NN forKey:@"PostNotification"];
	[acknowledgedRiskSpec setProperty:AIRKEEPER_IDENTIFIER forKey:@"defaults"];
	
	NSString *hashedAck = [AKPUtilities hashedAck256];
	if (![[self readPreferenceValue:acknowledgedRiskSpec] isEqualToString:hashedAck]){
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️⚠️⚠️ WARNING ⚠️⚠️⚠️" message:@"Any changes made in this section WILL persist in non-jailbroken mode. The tweak author is not responsible for any issue may or may not arise. Only proceed if you understand." preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"I Understand" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
			[self setPreferenceValue:hashedAck specifier:acknowledgedRiskSpec];
		}];
		
		UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
			[self.navigationController popToRootViewControllerAnimated:YES];
		}];
		
		[alert addAction:yesAction];
		[alert addAction:noAction];
		
		[self presentViewController:alert animated:YES completion:nil];
	}
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier{
	[AKPUtilities setValue:value forKey:[specifier propertyForKey:@"key"]];
}

-(id)readPreferenceValue:(PSSpecifier *)specifier{
	return [AKPUtilities valueForKey:[specifier propertyForKey:@"key"] defaultValue:[specifier propertyForKey:@"default"]];
}
@end
