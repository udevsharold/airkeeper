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

@interface NEAppRule : NSObject
@property (readonly) NSString *matchSigningIdentifier;
@property (copy) NSArray *matchDomains;
@property (assign) BOOL noRestriction;
@property (copy) NSString * matchPath;
@property (copy) NSArray<NEAppRule *> *matchTools; /*spawned process*/
- (instancetype)initWithSigningIdentifier:(NSString *)signingIdentifier;
- (BOOL)signingIdentifierAllowed:(NSString *)signingIdentifier domainsOrAccountsRequired:(BOOL *)required;
@end

typedef NS_ENUM(NSInteger, NEPathRuleNetworkBehavior) {
	NEPathRuleNetworkBehaviorAllow = 0,
	NEPathRuleNetworkBehaviorDeny = 1,
	NEPathRuleNetworkBehaviorAllowWhileRoaming = 2,
};

@interface NEPathRule : NEAppRule
- (instancetype)initDefaultPathRule;
@property (readonly, getter=isDefaultPathRule) BOOL defaultPathRule;
@property NEPathRuleNetworkBehavior cellularBehavior;
@property NEPathRuleNetworkBehavior wifiBehavior;
@property BOOL denyCellularFallback;
- (BOOL)supportsCellularBehavior:(NEPathRuleNetworkBehavior)cellularBehavior;
- (BOOL)supportsWiFiBehavior:(NEPathRuleNetworkBehavior)wifiBehavior;
@end

@interface NEVPNProtocol : NSObject
@property (copy) NSUUID * identifier;
@end

@interface NEVPN : NSObject
@property (getter=isEnabled) BOOL enabled;
@property (getter=isOnDemandEnabled) BOOL onDemandEnabled;
@property (copy) NSArray *onDemandRules;
@property (copy) NEVPNProtocol *protocol;
@property (nonatomic, assign, getter=isDisconnectOnDemandEnabled) BOOL disconnectOnDemandEnabled;
@property (copy) NSArray * exceptionApps; 
@end

typedef NS_ENUM(NSInteger, NEVPNAppTunnelType) {
	NEVPNAppTunnelTypePacket = 1,
	NEVPNAppTunnelTypeAppProxy = 2,
};

@interface NEVPNApp : NEVPN
@property NEVPNAppTunnelType tunnelType;
@property (copy) NSArray *appRules;
@property (assign) BOOL restrictDomains;
@property (copy) NSArray * excludedDomains;
@property (assign) BOOL noRestriction;
@end

typedef NS_ENUM(NSInteger, NEConfigurationGrade) {
	NEConfigurationGradeEnterprise = 1,
	NEConfigurationGradePersonal = 2,
	NEConfigurationGradeSystem = 3,
	NEConfigurationGradeMax = NEConfigurationGradeSystem,
};

@interface NEConfiguration : NSObject
- (id)initWithName:(NSString *)name grade:(NEConfigurationGrade)grade;
@property (readonly) NEConfigurationGrade grade;
@property (readonly) NSUUID *identifier;
@property (copy) NSString *name;
@property (copy) NEVPN *VPN;
@property (copy) NEVPNApp *appVPN;
@end

@interface NEConfigurationManager : NSObject
+ (NEConfigurationManager *)sharedManager;
+ (NEConfigurationManager *)sharedManagerForAllUsers;
- (void)loadConfigurationsWithCompletionQueue:(dispatch_queue_t)queue handler:(void (^)(NSArray *configurations, NSError *error))handler;
- (void)saveConfiguration:(NEConfiguration *)configuration withCompletionQueue:(dispatch_queue_t)queue handler:(void (^)(NSError *error))handler;
- (void)setChangedQueue:(dispatch_queue_t)queue andHandler:(void (^)(NSArray *changedIDs))handler;
- (void)removeConfiguration:(NEConfiguration *)configuration withCompletionQueue:(dispatch_queue_t)queue handler:(void (^)(NSError *error))handler;
@end
