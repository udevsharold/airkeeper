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

#import "../Common.h"

@protocol AKPPolicyControlling <NSObject>
@required
-(void)setPolicyWithInfo:(NSData *)info reply:(void (^)(BOOL success, NSArray <NSNumber *>*policyIDs))reply;
-(void)setPolicyWithInfoArray:(NSData *)data reply:(void (^)(NSArray <NSNumber *>*successes, NSData *policies))reply;
-(void)readPolicyWithInfo:(NSData *)info reply:(void (^)(AKPPolicyType policy))reply;
-(void)currentPoliciesWithReply:(void (^)(NSData *policies))reply;
-(void)initializeSessionWithReply:(void (^)(BOOL finished))reply;
@end
