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

#ifdef __cplusplus
extern "C" {
#endif

typedef const void *SecTaskRef;
SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef allocator);
CFTypeRef SecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement, CFErrorRef *error);

#ifdef __cplusplus
}
#endif

#import "PrivateHeaders.h"

@interface AKPNetworkConfigurationUtilities : NSObject
@property(nonatomic, strong) NSString *bundleIdentifier;
@property(nonatomic, strong) NEConfiguration *selectedVPNConfiguration;
+(void)loadConfigurationsWithCompletion:(void (^)(NSArray * configurations, NSError * error))handler;
+(void)saveConfiguration:(NEConfiguration *)neConfig handler:(void(^)(NSError * error))handler;
+(void)removeConfiguration:(NEConfiguration *)configuration handler:(void (^)(NSError *error))handler;
@end
