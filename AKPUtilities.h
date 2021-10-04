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

#define kCTCellularDataUsagePolicy CFSTR("kCTCellularDataUsagePolicy")
#define kCTWiFiDataUsagePolicy CFSTR("kCTWiFiDataUsagePolicy")
#define kCTCellularDataUsagePolicyDeny CFSTR("kCTCellularDataUsagePolicyDeny")
#define kCTCellularDataUsagePolicyAlwaysAllow CFSTR("kCTCellularDataUsagePolicyAlwaysAllow")

typedef void* CTServerConnectionRef;

#ifdef __cplusplus
extern "C" {
#endif

CTServerConnectionRef _CTServerConnectionCreate(CFAllocatorRef, void *, void*);
int64_t _CTServerConnectionSetCellularUsagePolicy(CTServerConnectionRef ct, CFStringRef identifier, CFDictionaryRef policies);
int64_t _CTServerConnectionCopyCellularUsagePolicy(CTServerConnectionRef ct, CFStringRef identifier, CFMutableDictionaryRef *policies);

#ifdef __cplusplus
}
#endif

@interface AKPUtilities : NSObject
+(CTServerConnectionRef)ctConnection;
+(void)setPolicy:(AKPPolicyType)type forIdentifier:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success;
+(void)setPolicyForAll:(AKPPolicyType)type connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success;
+(AKPPolicyType)readPolicy:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success;
+(NSString *)policyAsString:(NSString *)identifier connection:(CTServerConnectionRef)ctConnection success:(BOOL *)success;
+(NSString *)stringForPolicy:(AKPPolicyType)type;
+(void)restoreAllChanged:(CTServerConnectionRef)ctConnection;
+(NSDictionary *)exportPolicies:(CTServerConnectionRef)ctConnection;
+(void)exportPoliciesTo:(NSString *)file connection:(CTServerConnectionRef)ctConnection;
+(BOOL)importPolicies:(NSDictionary *)policies connection:(CTServerConnectionRef)ctConnection;
@end
