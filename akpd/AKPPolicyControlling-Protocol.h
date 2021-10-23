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
-(void)setPolicyWithInfo:(NSData *)info reply:(void (^)(NSError *error))reply;
-(void)setPolicyWithInfo:(NSData *)data wait:(BOOL)wait reply:(void (^)(NSError *error))reply;
-(void)setPolicyWithInfoArray:(NSData *)data reply:(void (^)(NSError *error))reply;
-(void)initializeSessionAndWait:(BOOL)wait reply:(void (^)(NSError *error))reply;
@end
