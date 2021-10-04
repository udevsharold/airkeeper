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
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

#define kCTCellularDataUsagePolicy CFSTR("kCTCellularDataUsagePolicy")
#define kCTWiFiDataUsagePolicy CFSTR("kCTWiFiDataUsagePolicy")
#define kCTCellularDataUsagePolicyDeny CFSTR("kCTCellularDataUsagePolicyDeny")
#define kCTCellularDataUsagePolicyAlwaysAllow CFSTR("kCTCellularDataUsagePolicyAlwaysAllow")

#ifdef __cplusplus
extern "C" {
#endif

CTServerConnectionRef _CTServerConnectionCreate(CFAllocatorRef, void *, void*);
int64_t _CTServerConnectionSetCellularUsagePolicy(CTServerConnectionRef ct, CFStringRef identifier, CFDictionaryRef policies);
int64_t _CTServerConnectionCopyCellularUsagePolicy(CTServerConnectionRef ct, CFStringRef identifier, CFMutableDictionaryRef *policies);

#ifdef __cplusplus
}
#endif

@interface AKPPolicyConfiguration : PSViewController <UITableViewDelegate, UITableViewDataSource>{
	CTServerConnectionRef _ctConnection;
	NSIndexPath *_selectedIndexPath;
	UITableView *_tableView;
}
@end
