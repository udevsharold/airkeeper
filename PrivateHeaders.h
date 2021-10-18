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
#import <xpc/xpc.h>

@interface NEAppRule : NSObject
@property (readonly) NSString *matchSigningIdentifier;
@property (copy) NSArray *matchDomains;
@property (assign) BOOL noRestriction;
@property (copy) NSString * matchPath;
@property (assign) BOOL noDivertDNS;
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

typedef NS_ENUM(NSInteger, NEKeychainItemDomain) {
	NEKeychainItemDomainSystem,
	NEKeychainItemDomainUser,
};

@interface NEKeychainItem : NSObject
@property (copy) NSString * identifier;
@property long long domain;
@property(copy) NSString *accessGroup;
- (id)initWithPassword:(NSString *)password domain:(NEKeychainItemDomain)domain accessGroup:(NSString *)accessGroup;
- (NSString *)copyPassword;
- (id)initWithIdentifier:(NSString *)identifier domain:(NEKeychainItemDomain)domain accessGroup:(NSString *)accessGroup;
@end

@interface NEVPNProtocol : NSObject
@property (copy) NSUUID * identifier;
@property (assign) BOOL disconnectOnIdle;
@property (assign) int disconnectOnIdleTimeout;
@property (assign) BOOL disconnectOnSleep;
@property (copy) NEKeychainItem * passwordKeychainItem;
@property (assign) BOOL enforceRoutes; 
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

@interface NEProcessInfo : NSObject
+(void)clearUUIDCache;
+(id)copyUUIDForSingleArch:(int)arg1 ;
+(id)copyUUIDsFromExecutable:(const char*)arg1 ;
+(NSArray *)copyUUIDsForExecutable:(NSString *)arg1 ;
+(void)initGlobals;
+(id)copyNEHelperUUIDs;
+(BOOL)is64bitCapable;
+(id)copyDNSUUIDs;
+(NSArray *)copyUUIDsForBundleID:(id)arg1 uid:(unsigned)arg2 ;
+(id)copyUUIDsForFatBinary:(int)arg1 ;
-(id)init;
@end

@interface NEPolicyCondition : NSObject
@property (getter=isNegative) BOOL negative;
+ (NEPolicyCondition *)effectiveApplication:(NSUUID *)applicationUUID;
+ (NEPolicyCondition *)realApplication:(NSUUID *)applicationUUID;
+ (NEPolicyCondition *)domain:(NSString *)domain;
+ (NEPolicyCondition *)signingIdentifier:(NSString *)signingIdentifier;
+ (NEPolicyCondition *)isInbound;
+ (NEPolicyCondition *)allInterfaces;
+ (NEPolicyCondition *)uid:(uid_t)uid;
@end

typedef NS_ENUM(NSInteger, NEPolicyRouteRuleAction) {
	NEPolicyRouteRuleActionAllow = 1,
	NEPolicyRouteRuleActionDeny = 2,
};

typedef NS_ENUM(NSInteger, NEPolicyRouteRuleType) {
	NEPolicyRouteRuleTypeNone = 0,
	NEPolicyRouteRuleTypeExpensive = 1,
	NEPolicyRouteRuleTypeCellular = 2,
	NEPolicyRouteRuleTypeWiFi = 3,
	NEPolicyRouteRuleTypeWired = 4,
};

@interface NEPolicyRouteRule : NSObject
+ (NEPolicyRouteRule *)routeRuleWithAction:(NEPolicyRouteRuleAction)action forType:(NEPolicyRouteRuleType)type;
@end

@interface NEPolicyResult : NSObject
+ (NEPolicyResult *)pass;
+ (NEPolicyResult *)drop;
+ (NEPolicyResult *)routeRules:(NSArray<NEPolicyRouteRule *> *)routeRules;
@end

@interface NEPolicy : NSObject
- (instancetype)initWithOrder:(uint32_t)order result:(NEPolicyResult *)result conditions:(NSArray<NEPolicyCondition *> *)conditions;
@end

typedef NS_ENUM(NSInteger, NEPolicySessionPriority) {
	NEPolicySessionPriorityDefault = 0,
	NEPolicySessionPriorityControl = 1,
	NEPolicySessionPriorityPrivilegedTunnel = 2,
	NEPolicySessionPriorityHigh = 3,
	NEPolicySessionPriorityLow = 4,
};

@interface NEPolicySession : NSObject
@property (retain) NSMutableDictionary * policies;
@property NEPolicySessionPriority priority;
- (NSUInteger)addPolicy:(NEPolicy *)policy;
- (BOOL)removePolicyWithID:(NSUInteger)policyID;
- (BOOL)removeAllPolicies;
- (BOOL)apply;
@end

@interface NSXPCConnection (Private)
-(id)valueForEntitlement:(id)ent;
-(xpc_connection_t)_xpcConnection;
@end
