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
#import "AKPPolicyControlling-Protocol.h"
#import "../PrivateHeaders.h"
#import <os/lock.h>

@interface AKPDaemon : NSObject <AKPPolicyControlling>{
	NEPolicySession *_policySession;
	dispatch_block_t _terminationVerificationBlock;
	NSInteger _processing;
	BOOL _stopTask;
	NSMutableDictionary *_requestCount;
	os_unfair_lock _lock;
	NSString *_processingAccount;
}
@property (nonatomic, assign) BOOL initialized;
+(instancetype)sharedInstance;
-(void)queueTerminationIfNecessaryWithDelay:(int64_t)delay;
@end
