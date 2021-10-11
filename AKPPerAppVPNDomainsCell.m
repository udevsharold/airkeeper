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

#import "AKPPerAppVPNDomainsCell.h"
#import "AKPApplicationController.h"

@implementation AKPPerAppVPNDomainsCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier specifier:(PSSpecifier*)specifier{
	
	if (self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier]){
	}
	
	return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier*)specifier{
	
	[super refreshCellContentsWithSpecifier:specifier];
	if ([specifier.target respondsToSelector:@selector(perAppVPNDomains)]){
		NSArray *domains = [(AKPApplicationController *)(specifier.target) valueForKey:@"_lastDomains"];
		if (domains.count > 1){
			self.detailTextLabel.text = [NSString stringWithFormat:@"%@, ...", domains[0]];
		}else{
			self.detailTextLabel.text = [domains componentsJoinedByString:@", "];
		}
	}
}

@end
