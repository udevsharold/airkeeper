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
#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>

@implementation AKPApplicationListSubcontrollerController
-(instancetype)init{
	if (self = [super init]){
		_ctConnection = [AKPUtilities ctConnection];
	}
	return self;
}

-(NSString*)subtitleForApplicationWithIdentifier:(NSString*)applicationID{
	return [AKPUtilities policyAsString:applicationID connection:_ctConnection success:nil];
}

- (NSString*)previewStringForApplicationWithIdentifier:(NSString *)applicationID{
	AKPPolicyType type = [AKPUtilities readPolicy:applicationID connection:_ctConnection success:nil];
	return type != AKPPolicyTypeAllAllow ? [AKPUtilities stringForPolicy:type] : @"";
}

-(NSString*)osBuildVersion{
		return (__bridge NSString *)MGCopyAnswer(CFSTR("BuildVersion"));
}

-(NSString *)deviceUDID{
	return (__bridge NSString *)MGCopyAnswer(CFSTR("UniqueDeviceID"));
}

-(NSString *)hashedAck256{
	static NSMutableString *ret;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		const char* str = [NSString stringWithFormat:@"%@-%@", [self deviceUDID], [self osBuildVersion]].UTF8String;
		unsigned char result[CC_SHA256_DIGEST_LENGTH];
		CC_SHA256(str, (CC_LONG)strlen(str), result);
		ret = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
		for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++){
			[ret appendFormat:@"%02x",result[i]];
		}
	});
	return ret;
}

-(void)viewDidLoad{
	[super viewDidLoad];
	PSSpecifier *acknowledgedRiskSpec = [PSSpecifier preferenceSpecifierNamed:@"Acknowledged Risk" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
	[acknowledgedRiskSpec setProperty:@"acknowledgedRisk" forKey:@"key"];
	[acknowledgedRiskSpec setProperty:nil forKey:@"default"];
	[acknowledgedRiskSpec setProperty:PREFS_CHANGED_NN forKey:@"PostNotification"];
	[acknowledgedRiskSpec setProperty:AIRKEEPER_IDENTIFIER forKey:@"defaults"];

	NSString *hashedAck = [self hashedAck256];
	if (![[self readPreferenceValue:acknowledgedRiskSpec] isEqualToString:hashedAck]){
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️⚠️⚠️ WARNING ⚠️⚠️⚠️" message:@"Any changes made in this section will persist in non-jailbroken mode. The tweak author is not responsible for any issue may or may not arise. Only proceed if you understand." preferredStyle:UIAlertControllerStyleAlert];
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
@end
