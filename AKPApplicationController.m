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

#import "AKPApplicationController.h"
#import "AKPUtilities.h"
#import "AKPNetworkConfigurationUtilities.h"
#import "AKPApplicationListSubcontrollerController.h"

@implementation AKPApplicationController

-(instancetype)init{
	if (self = [super init]){
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSpecifiers) name:@"reloadSpecifiersNotification" object:nil];
		_ctConnection = [AKPUtilities ctConnection];
		_dummyConfig = [[NEConfiguration alloc] initWithName:@"Airkeeper Dummy Per-App" grade:NEConfigurationGradeEnterprise];
		_perAppVPNConfiguration = [AKPPerAppVPNConfiguration new];
		[AKPNetworkConfigurationUtilities loadConfigurationsWithCompletion:^(NSArray *configurations, NSError *error){
			_installedVPNs = [_perAppVPNConfiguration installedVPNConfigurations];
			_selectedVPNConfig = [_perAppVPNConfiguration masterConfigurationFrom:[_perAppVPNConfiguration residingConfigurationsForApp].firstObject] ?: _dummyConfig;
			_lastDomains = [self perAppVPNDomains];
			if (_wirelessDataSpec) [self reloadSpecifier:_wirelessDataSpec animated:YES];
			if (_installedVPNsSpec){
				[self reloadInstalledVPNsData];
				[self reloadSpecifier:_installedVPNsSpec animated:YES];
			}
			if (_perAppVPNEnabledSpec) [self reloadSpecifier:_perAppVPNEnabledSpec animated:YES];
			if (_vpnDomainsSpec){
				[_vpnDomainsSpec setProperty:@([_perAppVPNConfiguration requiredMatchingDomains]) forKey:@"enabled"];
				[self reloadSpecifier:_vpnDomainsSpec animated:YES];
			}
		}];
	}
	return self;
}

-(void)dealloc{
	if (_ctConnection) CFRelease(_ctConnection);
}

-(PSSpecifier *)specifierForCache{
	static PSSpecifier *cacheSpec;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cacheSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
		[cacheSpec setProperty:@"cacheValue" forKey:@"key"];
		[cacheSpec setProperty:nil forKey:@"default"];
		[cacheSpec setProperty:PREFS_CHANGED_NN forKey:@"PostNotification"];
		[cacheSpec setProperty:AIRKEEPER_IDENTIFIER forKey:@"defaults"];
	});
	return cacheSpec;
}

-(void)setCacheValue:(id)value forSubkey:(NSString *)subkey{
	id cachedvalue = [self readPreferenceValue:[self specifierForCache]];
	NSMutableDictionary *cached = cachedvalue ? ((NSDictionary *)cachedvalue).mutableCopy : [NSMutableDictionary dictionary];
	cached[[self subkeyNameForComponent:subkey]] = value;
	[self setPreferenceValue:cached specifier:[self specifierForCache]];
}

-(id)readCacheValueForSubkey:(NSString *)subkey{
	NSDictionary *cached = [self readPreferenceValue:[self specifierForCache]];
	return cached ? cached[[self subkeyNameForComponent:subkey]] : nil;
}

-(NSString *)subkeyNameForComponent:(NSString *)componentName{
	return [NSString stringWithFormat:@"%@+%@", _bundleIdentifier, componentName];
}

-(void)reloadInstalledVPNsData{
	NSMutableArray *vpnValues = @[_dummyConfig].mutableCopy;
	[vpnValues addObjectsFromArray:_installedVPNs];
	NSMutableArray *vpnTitles = @[@"None"].mutableCopy;
	[vpnTitles addObjectsFromArray:[_installedVPNs valueForKey:@"name"]];
	[_installedVPNsSpec setValues:vpnValues.copy titles:vpnTitles.copy];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	_bundleIdentifier = [self specifier].identifier;
	_perAppVPNConfiguration.bundleIdentifier = _bundleIdentifier;
	self.title = [self specifier].name;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *rootSpecifiers = [[NSMutableArray alloc] init];
		
		//wireless data section
		PSSpecifier *connectivityGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Connectivity" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:connectivityGroupSpec];
		
		//Wireless Data
		_wirelessDataSpec = [PSSpecifier preferenceSpecifierNamed:@"Wireless Data" target:self set:@selector(setWirelessDataPolicy:specifier:) get:@selector(readWirelessDataPolicy:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
		[_wirelessDataSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
		NSMutableArray *policyTitles = [NSMutableArray array];
		for (int i = 0; i < 4; i++){
			[policyTitles addObject:[AKPUtilities stringForPolicy:i]];
		}
		[_wirelessDataSpec setValues:@[@(AKPPolicyTypeNone), @(AKPPolicyTypeCellularAllow), @(AKPPolicyTypeWiFiAllow), @(AKPPolicyTypeAllAllow)] titles:policyTitles];
		[_wirelessDataSpec setProperty:@"VPN Profile" forKey:@"label"];
		[rootSpecifiers addObject:_wirelessDataSpec];
		
		//VPN section
		PSSpecifier *vpnGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Per App VPN" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:vpnGroupSpec];
		
		//Installed VPNs
		_installedVPNsSpec = [PSSpecifier preferenceSpecifierNamed:@"VPN Profile" target:self set:@selector(setVPNProfile:specifier:) get:@selector(readVPNProfile:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
		[_installedVPNsSpec setProperty:NSClassFromString(@"PSLinkListCell") forKey:@"cellClass"];
		[self reloadInstalledVPNsData];
		[_installedVPNsSpec setProperty:@"VPN Profile" forKey:@"label"];
		[rootSpecifiers addObject:_installedVPNsSpec];
		_specifiers = rootSpecifiers;
		
		//Domains
		_vpnDomainsSpec = [PSSpecifier preferenceSpecifierNamed:@"Filter Domains" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[_vpnDomainsSpec setProperty:NSClassFromString(@"AKPPerAppVPNDomainsCell") forKey:@"cellClass"];
		[_vpnDomainsSpec setProperty:@"Filter Domains" forKey:@"label"];
		[_vpnDomainsSpec setButtonAction:@selector(editDomains)];
		[_vpnDomainsSpec setProperty:@([_perAppVPNConfiguration requiredMatchingDomains]) forKey:@"enabled"];
		[rootSpecifiers addObject:_vpnDomainsSpec];
		
	}
	return _specifiers;
}

-(void)popErrorAlert:(NSError *)error onOk:(void (^)())okHandler{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Error: %ld", error.code] message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
		okHandler();
	}];
	[alert addAction:okAction];
	[self presentViewController:alert animated:YES completion:nil];
}

-(void)setVPNProfile:(id)value specifier:(PSSpecifier *)specifier{
	if (value){
		NSUInteger idx = [_installedVPNs indexOfObject:value];
		
		__weak typeof(self) weakSelf = self;
		
		if (_perAppVPNConfiguration.saving){
			UIAlertController *savingAlert = [UIAlertController alertControllerWithTitle:@"Saving..." message:nil preferredStyle:UIAlertControllerStyleAlert];
			[self presentViewController:savingAlert animated:YES completion:^{
				[_perAppVPNConfiguration reloadConfigurations:^{
					[savingAlert dismissViewControllerAnimated:YES completion:^{
					}];
				}];
			}];
		}
		
		void (^switchConfig)(NSArray <NSString *>*) = ^(NSArray <NSString *>* theDomains){
			NEConfiguration *prevConfig = _selectedVPNConfig.copy;
			if (idx != NSNotFound){
				_selectedVPNConfig = _installedVPNs[idx];
				[_perAppVPNConfiguration switchConfig:prevConfig to:_selectedVPNConfig domains:theDomains path:nil completion:^(NSError *error){
					if (error && ![_selectedVPNConfig isEqual:prevConfig]){
						_selectedVPNConfig = _dummyConfig;
						[weakSelf popErrorAlert:error onOk:^{
							[weakSelf reloadSpecifiers];
							[weakSelf.navigationController popViewControllerAnimated:YES];
						}];
					}
				}];
			}else{
				_selectedVPNConfig = _dummyConfig;
				[_perAppVPNConfiguration switchConfig:prevConfig to:nil domains:theDomains path:nil completion:^(NSError *error){
					if (error && ![_selectedVPNConfig isEqual:prevConfig]){
						_selectedVPNConfig = _dummyConfig;
						_lastDomains = nil;
						[weakSelf popErrorAlert:error onOk:^{
							[weakSelf reloadSpecifiers];
							[weakSelf.navigationController popViewControllerAnimated:YES];
						}];
					}
				}];
			}
			[self reloadGranparentSpecifier:specifier type:AKPReloadSpecifierTypePerAppVPN];
		};
		
		NSArray <NSString *> *domains = nil;
		if ([_perAppVPNConfiguration requiredMatchingDomains]){
			_lastDomains = [self perAppVPNDomains];
			if (_lastDomains.count > 0){
				switchConfig(_lastDomains);
			}else{
				[self addDomainsAndSave:NO withResult:^(NSArray <NSString *> *domains){
					_lastDomains = domains;
					switchConfig(domains);
					[weakSelf reloadSpecifiers];
				} onError:^(NSError *error, NSArray <NSString *> *domains){
					if (error && ![[NSSet setWithArray:domains] isEqualToSet:[NSSet setWithArray:_lastDomains]]){
						_lastDomains = domains;
						_selectedVPNConfig = _dummyConfig;
						[weakSelf popErrorAlert:error onOk:^{
							[weakSelf reloadSpecifiers];
							[weakSelf.navigationController popViewControllerAnimated:YES];
						}];
					}
				}];
			}
		}else{
			_lastDomains = domains;
			switchConfig(domains);
		}
	}
}

-(id)readVPNProfile:(PSSpecifier *)specifier{
	return _selectedVPNConfig ?: _dummyConfig;
}

-(void)reloadGranparentSpecifier:(PSSpecifier *)specifier type:(AKPReloadSpecifierType)type{
	AKPApplicationController *parentController = (AKPApplicationController *)(specifier.target);
	AKPApplicationListSubcontrollerController *grandparentController = (AKPApplicationListSubcontrollerController *)(parentController.specifier.target);
	if (type == AKPReloadSpecifierTypePerAppVPN && [grandparentController respondsToSelector:@selector(reloadConfigurationsAndReloadSpecifier:)]){
		[grandparentController reloadConfigurationsAndReloadSpecifier:[grandparentController specifierForApplicationWithIdentifier:_bundleIdentifier]];
	}else if (type == AKPReloadSpecifierTypeConnectivity && [grandparentController respondsToSelector:@selector(specifierForApplicationWithIdentifier:)]){
		[grandparentController reloadSpecifier:[grandparentController specifierForApplicationWithIdentifier:_bundleIdentifier] animated:NO];
	}
}

-(void)setWirelessDataPolicy:(id)value specifier:(PSSpecifier *)specifier{
	BOOL success = NO;
	[AKPUtilities setPolicy:[value intValue] forIdentifier:_bundleIdentifier connection:_ctConnection success:&success];
	if (!success) [self reloadSpecifier:specifier animated:YES];
	[self reloadGranparentSpecifier:specifier type:AKPReloadSpecifierTypeConnectivity];
}

-(id)readWirelessDataPolicy:(PSSpecifier *)specifier{
	return @([AKPUtilities readPolicy:_bundleIdentifier connection:_ctConnection success:nil]);
}

-(NSArray <NSString *>*)perAppVPNDomains{
	NSArray <NEAppRule *>*appRules = [_perAppVPNConfiguration perAppVPNDomainsFrom:_selectedVPNConfig];
	if (appRules.count > 0){
		return appRules.firstObject.matchDomains;
	}
	return nil;
}

-(NSString *)perAppVPNDomainsString:(NSString *)sep{
	return [[self perAppVPNDomains] componentsJoinedByString:sep];
}

-(void)editDomains{
	__weak typeof(self) weakSelf = self;
	[self addDomainsAndSave:YES withResult:nil onError:^(NSError *error, NSArray <NSString *> *domains){
		_lastDomains = domains;
		if (error && ![[NSSet setWithArray:domains] isEqualToSet:[NSSet setWithArray:_lastDomains]]){
			[weakSelf popErrorAlert:error onOk:^{
				[weakSelf reloadSpecifiers];
			}];
		}else{
			[weakSelf reloadSpecifiers];
		}
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

-(void)addDomainsAndSave:(BOOL)save withResult:(void (^)(NSArray <NSString *>*))result onError:(void(^)(NSError *, NSArray <NSString *>*))errorHandler{
	[self popTextViewWithTitle:@"Domains to Use VPN" message:@"Each domain seperated by new line.\n\n\n\n\n\n" text:[(_lastDomains ?: [self readCacheValueForSubkey:@"domains"]) componentsJoinedByString:@"\n"] onDone:^(NSArray <NSString *> *domains){
		if (save){
			[_perAppVPNConfiguration setPerAppVPNEnabled:YES domains:domains path:nil forVPNConfiguration:_selectedVPNConfig completion:^(NSError *error){
				if (errorHandler) errorHandler(error, domains);
			}];
		}
		[self setCacheValue:domains forSubkey:@"domains"];
		if (result) result(domains);
	} onCancel:^(id ret){
		if (result) result(ret);
	}];
}

@end
