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
#import "PrivateHeaders.h"

@interface AKPNEUtilities : NSObject
+(NSString *)stringForTrafficRule:(AKPDaemonTrafficRule)rule simple:(BOOL)simple;
+(NSArray <NEPolicyRouteRule *>* )policyAsRouteRules:(AKPPolicyType)policy;
#ifndef AKPD
+(void)setPolicyWithInfo:(NSDictionary *)info reply:(void (^)(NSError *error))reply;
+(void)setPolicyWithInfoArray:(NSArray *)infos reply:(void (^)(NSArray <NSNumber *>*successes, NSDictionary *policies, NSError *error))reply;
+(void)setPolicyForAll:(AKPPolicyType)type reply:(void (^)(NSArray <NSNumber *>*successes, NSDictionary *policies, NSError *error))reply;
+(void)readPolicyWithInfo:(NSDictionary *)info reply:(void (^)(AKPPolicyType policy))reply;
+(void)currentPoliciesWithReply:(void (^)(NSDictionary *policies))reply;
+(void)initializeSessionWithReply:(void (^)(BOOL finished))reply;
#endif
@end
