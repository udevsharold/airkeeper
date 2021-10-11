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

#import "Common.h"
#import "AKPPerAppVPNConfiguration.h"
#import "AKPNetworkConfigurationUtilities.h"

@implementation AKPPerAppVPNConfiguration

-(instancetype)init{
	if (self  = [super init]){
		[[NEConfigurationManager sharedManagerForAllUsers] setChangedQueue:dispatch_get_main_queue() andHandler:^(NSArray *changedIDs){
			[self reloadConfigurations:nil];
		}];
		[self reloadConfigurations:nil];
	}
	return self;
}

-(void)reloadConfigurations:(void (^)())handler{
	[AKPNetworkConfigurationUtilities loadConfigurationsWithCompletion:^(NSArray *configurations, NSError *error){
		_configurations = configurations.mutableCopy;
		self.saving = NO;
		if (handler) handler();
	}];
}

-(NSArray <NEConfiguration *>* )installedVPNConfigurations{
	NSArray *configs;
	if (_configurations.count > 0){
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.VPN != nil AND SELF.appVPN == nil"];
		return [_configurations filteredArrayUsingPredicate:predicate];
	}
	return configs;
}

-(NEConfiguration *)masterConfigurationFrom:(NEConfiguration *)neConfig{
	for (NEConfiguration *config in _configurations){
		if ([config.VPN.protocol.identifier isEqual:neConfig.appVPN.protocol.identifier]){
			return config;
		}
	}
	return nil;
}

-(NEConfiguration *)perAppVPNConfigurationFrom:(NEConfiguration * )masterConfig create:(BOOL)createNew{
	NEConfiguration *neConfig;
	if (_configurations.count > 0){
		for (NEConfiguration *config in _configurations){
			if ([config.appVPN.protocol.identifier isEqual:masterConfig.VPN.protocol.identifier]){
				return config;
			}
		}
		if (createNew){
			neConfig = [[NEConfiguration alloc] initWithName:[NSString stringWithFormat:@"%@ Per-App (AirKeeper)", masterConfig.name] grade:masterConfig.grade];
			NEVPNApp *appVPN = [NEVPNApp new];
			appVPN.protocol = masterConfig.VPN.protocol;
			appVPN.onDemandRules = masterConfig.VPN.onDemandRules;
			appVPN.tunnelType = NEVPNAppTunnelTypePacket;
			appVPN.protocol.passwordKeychainItem = [[NEKeychainItem alloc] initWithIdentifier:neConfig.identifier.UUIDString domain:masterConfig.VPN.protocol.passwordKeychainItem.domain accessGroup:masterConfig.VPN.protocol.passwordKeychainItem.accessGroup];
			neConfig.appVPN = appVPN;
		}
	}
	return neConfig;
}

-(NSArray <NEAppRule *>*)_rulesForApp:(NSString *)identifier inConfiguration:(NEConfiguration *)neConfig{
	if (identifier && neConfig){
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.matchSigningIdentifier == %@", identifier];
		return [neConfig.appVPN.appRules filteredArrayUsingPredicate:predicate];
	}
	return nil;
}

-(NSArray <NEAppRule *>*)rulesForAppIn:(NEConfiguration *)neConfig{
	return [self _rulesForApp:self.bundleIdentifier inConfiguration:neConfig];
}

-(NSArray <NEAppRule *>*)perAppVPNDomainsFrom:(NEConfiguration *)neConfig{
	return [self rulesForAppIn:[self perAppVPNConfigurationFrom:neConfig create:NO]];
}

-(NSArray <NEConfiguration *>*)_residingConfigurationsForApp:(NSString *)identifier{
	NSMutableArray <NEConfiguration *> *residingConfigurations = [NSMutableArray array];
	if (_configurations.count > 0){
		for (NEConfiguration *config in _configurations){
			if ([self _rulesForApp:identifier inConfiguration:config].count > 0){
				[residingConfigurations addObject:config];
			}
		}
	}
	return residingConfigurations;
}

-(NSArray <NEConfiguration *>*)residingConfigurationsForApp{
	return [self _residingConfigurationsForApp:self.bundleIdentifier];
}

-(NEConfiguration *)removeAppRulesForApp:(NSString *)identifier andAdd:(NSArray *)addRules inConfiguration:(NEConfiguration *)neConfig{
	NSMutableArray *newAppRules = neConfig.appVPN.appRules ? neConfig.appVPN.appRules.mutableCopy : [NSMutableArray array];
	NSArray <NEAppRule *>* appRules = [self _rulesForApp:identifier inConfiguration:neConfig];
	[newAppRules removeObjectsInArray:appRules];
	[newAppRules addObjectsFromArray:addRules];
	neConfig.appVPN.appRules = newAppRules.copy;
	return neConfig;
}

-(BOOL)perAppVPNEnabled{
	return [self residingConfigurationsForApp].count > 0;
}

-(BOOL)disconnectOnSleepEnabled:(NEConfiguration *)masterConfig{
	NEConfiguration *perAppConfig = [self perAppVPNConfigurationFrom:masterConfig create:NO];
	return perAppConfig ? perAppConfig.appVPN.protocol.disconnectOnSleep : NO;
}

-(BOOL)_requiredMatchingDomainsForApp:(NSString *)identifier{
	NEAppRule *dummyAppRule = [[NEAppRule alloc] initWithSigningIdentifier:identifier];
	BOOL requiredDomains = NO;
	[dummyAppRule signingIdentifierAllowed:identifier domainsOrAccountsRequired:&requiredDomains];
	return requiredDomains;
}

-(BOOL)requiredMatchingDomains{
	return [self _requiredMatchingDomainsForApp:self.bundleIdentifier];
}

-(void)_switchConfig:(NEConfiguration *)fromConfig to:(NEConfiguration *)toConfig domains:(NSArray <NSString *>* )domains path:(NSString *)path disconnectOnSleep:(BOOL)disconnectOnSleep forApp:(NSString *)identifier completion:(void(^)(NSError *error))handler{
	
	NSArray <NEConfiguration *>*residingConfigurations = [self _residingConfigurationsForApp:identifier];
	
	NSArray *prevDomains = [self rulesForAppIn:[self perAppVPNConfigurationFrom:fromConfig create:NO]];
	
	if (residingConfigurations.count > 0){
		for (NEConfiguration *other in residingConfigurations){
			NEConfiguration *cleanedOther = [self removeAppRulesForApp:identifier andAdd:nil inConfiguration:other.copy];
			self.saving = YES;
			[AKPNetworkConfigurationUtilities saveConfiguration:cleanedOther handler:^(NSError *error){
				if (error) self.saving = NO;
			}];
		}
	}
	
	[self _setPerAppVPN:identifier enabled:(toConfig ? YES : NO) domains:(domains ?: ([self _requiredMatchingDomainsForApp:identifier] ? prevDomains : nil)) path:path disconnectOnSleep:disconnectOnSleep forVPNConfiguration:toConfig withRules:nil completion:^(NSError *error){
		if (handler) handler(error);
	}];
	
}

-(void)switchConfig:(NEConfiguration *)fromConfig to:(NEConfiguration *)toConfig domains:(NSArray <NSString *>* )domains path:(NSString *)path disconnectOnSleep:(BOOL)disconnectOnSleep completion:(void(^)(NSError *error))handler{
	
	[self _switchConfig:fromConfig to:toConfig domains:([self requiredMatchingDomains] ? domains : nil) path:path disconnectOnSleep:disconnectOnSleep forApp:self.bundleIdentifier completion:^(NSError *error){
		if (handler) handler(error);
	}];
}

-(NSString *)subkeyNameForComponent:(NSString *)componentName{
	return [NSString stringWithFormat:@"%@+%@", self.bundleIdentifier, componentName];
}

-(NSString *)subkeyNameForComponent:(NSString *)componentName configuration:(NEConfiguration *)neConfig{
	return [NSString stringWithFormat:@"%@+%@", neConfig.identifier.UUIDString, componentName];
}

-(void)_setPerAppVPN:(NSString *)identifier enabled:(BOOL)enabled domains:(NSArray <NSString *>* )domains path:(NSString *)path disconnectOnSleep:(BOOL)disconnectOnSleep forVPNConfiguration:(NEConfiguration * )vpnConfig withRules:(NSArray *)withRules completion:(void(^)(NSError *error))handler{
	if (_configurations.count > 0 && enabled){
		NEConfiguration *neConfig = [self perAppVPNConfigurationFrom:vpnConfig create:YES];
		NEAppRule *appRule = [[NEAppRule alloc] initWithSigningIdentifier:identifier];
		if (domains) appRule.matchDomains = domains;
		if (path.length > 0) appRule.matchPath = path;
		NSMutableArray *newRules = @[appRule].mutableCopy;
		[newRules addObjectsFromArray:withRules];
		neConfig = [self removeAppRulesForApp:identifier andAdd:newRules inConfiguration:neConfig.copy];
		neConfig.appVPN.enabled = YES;
		neConfig.appVPN.onDemandEnabled = YES;
		neConfig.appVPN.protocol.disconnectOnSleep = disconnectOnSleep;
		self.saving = YES;
		[AKPNetworkConfigurationUtilities saveConfiguration:neConfig handler:^(NSError *error){
			if (error) self.saving = NO;
			if (handler) handler(error);
		}];
	}else if (_configurations.count > 0){
		NEConfiguration *neConfig = [self perAppVPNConfigurationFrom:vpnConfig create:NO];
		if (neConfig){
			neConfig = [self removeAppRulesForApp:identifier andAdd:withRules inConfiguration:neConfig.copy];
			neConfig.appVPN.enabled = YES;
			neConfig.appVPN.onDemandEnabled = YES;
			neConfig.appVPN.protocol.disconnectOnSleep = disconnectOnSleep;
			self.saving = YES;
			[AKPNetworkConfigurationUtilities saveConfiguration:neConfig handler:^(NSError *error){
				if (error) self.saving = NO;
				if (handler) handler(error);
			}];
		}else{
			self.saving = NO;
			if (handler) handler(nil);
		}
	}else{
		if (handler) handler([NSError errorWithDomain:@"com.udevs.airkeeper" code:1 userInfo:@{@"Error reason":@"No configuraton found."}]);
	}
}

-(void)setPerAppVPNEnabled:(BOOL)enabled domains:(NSArray <NSString *>* )domains path:(NSString *)path disconnectOnSleep:(BOOL)disconnectOnSleep forVPNConfiguration:(NEConfiguration * )vpnConfig completion:(void(^)(NSError *error))handler{
	[self _setPerAppVPN:self.bundleIdentifier enabled:enabled domains:domains path:path disconnectOnSleep:disconnectOnSleep forVPNConfiguration:vpnConfig withRules:nil completion:^(NSError *error){
		if (handler) handler(error);
	}];
}

-(void)setDisconnectOnSleep:(BOOL)disconnectOnSleep forVPNConfiguration:(NEConfiguration * )vpnConfig completion:(void(^)(NSError *error))handler{
	if (_configurations.count > 0){
		NEConfiguration *neConfig = [self perAppVPNConfigurationFrom:vpnConfig create:NO];
		if (neConfig){
			neConfig.appVPN.protocol.disconnectOnSleep = disconnectOnSleep;
			self.saving = YES;
			[AKPNetworkConfigurationUtilities saveConfiguration:neConfig handler:^(NSError *error){
				if (error) self.saving = NO;
				if (handler) handler(error);
			}];
		}else{
			self.saving = NO;
			if (handler) handler(nil);
		}
	}else{
		if (handler) handler([NSError errorWithDomain:@"com.udevs.airkeeper" code:1 userInfo:@{@"Error reason":@"No configuraton found."}]);
	}
}

@end
