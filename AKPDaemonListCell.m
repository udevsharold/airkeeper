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

#import "AKPDaemonListCell.h"
#import "AKPDaemonListController.h"
#import "AKPUtilities.h"
#import "AKPNEUtilities.h"

@implementation AKPDaemonListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier specifier:(PSSpecifier*)specifier{
	
	if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier specifier:specifier]){
	}
	
	return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier*)specifier{
	[super refreshCellContentsWithSpecifier:specifier];
	if ([specifier.target respondsToSelector:@selector(policies)]){
		NSDictionary *info = [specifier propertyForKey:@"info"];
		
		NSMutableArray *previewsArray = [NSMutableArray array];
		
		NSNumber *retrievedPolicy = ((AKPDaemonListController *)(specifier.target)).policies[info[kPath]][kPolicy];
		AKPPolicyType policy = [retrievedPolicy ?: @(AKPPolicyTypeAllAllow) intValue];
		if (policy != AKPPolicyTypeAllAllow){
			[previewsArray addObject:[AKPUtilities stringForPolicy:policy]];
		}
		
		NSNumber *retrievedTrafficRule = ((AKPDaemonListController *)(specifier.target)).policies[info[kPath]][kSecundasRule];
		AKPDaemonTrafficRule trafficRule = [retrievedTrafficRule ?: @(AKPDaemonTrafficRulePassAllDomains) intValue];
		if (trafficRule != AKPDaemonTrafficRulePassAllDomains){
			[previewsArray addObject:[AKPNEUtilities stringForTrafficRule:trafficRule simple:YES]];
		}
		
		self.detailTextLabel.text = [previewsArray componentsJoinedByString:@" | "];
	}
}

@end
