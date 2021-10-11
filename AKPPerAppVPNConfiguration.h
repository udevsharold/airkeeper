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

#import "AKPPerAppVPNConfiguration.h"
#import "PrivateHeaders.h"

@interface AKPPerAppVPNConfiguration : NSObject{
	NSMutableArray <NEConfiguration *>*_configurations;
}
@property(nonatomic, strong) NSString *bundleIdentifier;
@property(nonatomic, assign) BOOL saving;
-(BOOL)perAppVPNEnabled;
-(void)setPerAppVPNEnabled:(BOOL)enabled domains:(NSArray <NSString *>* )domains path:(NSString *)path disconnectOnSleep:(BOOL)disconnectOnSleep forVPNConfiguration:(NEConfiguration * )vpnConfig completion:(void(^)(NSError * error))handler;
-(NSArray <NEConfiguration *>* )installedVPNConfigurations;
-(void)switchConfig:(NEConfiguration *)fromConfig to:(NEConfiguration *)toConfig domains:(NSArray <NSString *>* )domains path:(NSString *)path disconnectOnSleep:(BOOL)disconnectOnSleep completion:(void(^)(NSError *error))handler;
-(NSArray <NEConfiguration *>*)residingConfigurationsForApp;
-(NEConfiguration *)masterConfigurationFrom:(NEConfiguration *)neConfig;
-(NSArray <NEAppRule *>*)perAppVPNDomainsFrom:(NEConfiguration *)neConfig;
-(BOOL)requiredMatchingDomains;
-(void)reloadConfigurations:(void (^)())handler;
-(BOOL)disconnectOnSleepEnabled:(NEConfiguration *)masterConfig;
-(void)setDisconnectOnSleep:(BOOL)disconnectOnSleep forVPNConfiguration:(NEConfiguration * )vpnConfig completion:(void(^)(NSError *error))handler;
@end
