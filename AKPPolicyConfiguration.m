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

#import "AKPPolicyConfiguration.h"
#import "AKPApplicationListSubcontrollerController.h"
#import "AKPUtilities.h"

@implementation AKPPolicyConfiguration

- (NSString*)validIdentifier{
	return  [[self specifier] propertyForKey:@"applicationIdentifier"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return @"Wireless Data";
		default:
			return @"";
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
	switch (section) {
		case 0:
			return @"";
		default:
			return @"";
			
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return 4;
		default:
			return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AKPPolicyCell" forIndexPath:indexPath];
	
	if (cell == nil){
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AKPPolicyCell"];
	}
	
	switch(indexPath.section) {
		case 0: {
			switch (indexPath.row) {
				case 0:{
					BOOL enabled = [AKPUtilities readPolicy:[self validIdentifier] connection:_ctConnection success:nil] == AKPPolicyTypeNone;
					cell.textLabel.text = @"Off";
					cell.accessoryType = enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
					break;
				}
				case 1:{
					BOOL enabled = [AKPUtilities readPolicy:[self validIdentifier] connection:_ctConnection success:nil] == AKPPolicyTypeCellularAllow;
					cell.textLabel.text = @"Mobile Data";
					cell.accessoryType = enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
					break;
				}
				case 2:{
					BOOL enabled = [AKPUtilities readPolicy:[self validIdentifier] connection:_ctConnection success:nil] == AKPPolicyTypeWiFiAllow;
					cell.textLabel.text = @"Wi-Fi";
					cell.accessoryType = enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
					break;
				}
				case 3:{
					BOOL enabled = [AKPUtilities readPolicy:[self validIdentifier] connection:_ctConnection success:nil] == AKPPolicyTypeAllAllow;
					cell.textLabel.text = @"Wi-Fi & Mobile Data";
					cell.accessoryType = enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
					break;
				}
				default:
					break;
			}
			break;
		}
		default:
			break;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	UITableViewCell *cell =  [tableView cellForRowAtIndexPath:indexPath];
	UITableViewCell *oldCell =  [tableView cellForRowAtIndexPath:_selectedIndexPath];
	switch(indexPath.section) {
		case 0: {
			if (oldCell){
				oldCell.accessoryType = UITableViewCellAccessoryNone;
			}
			
			BOOL success = NO;
			[AKPUtilities setPolicy:indexPath.row forIdentifier:[self validIdentifier] connection:_ctConnection success:&success];
			if (success){
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
			
			_selectedIndexPath = indexPath;
			
			UIViewController *parentController = (UIViewController *)[self valueForKey:@"_parentController"];
			[(AKPApplicationListSubcontrollerController *)parentController reloadSpecifier:[(AKPApplicationListSubcontrollerController *)parentController specifierForApplicationWithIdentifier:[self validIdentifier]] animated:NO];
			}
			break;
		}
		default:
			break;
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	_ctConnection = [AKPUtilities ctConnection];
	_selectedIndexPath = [NSIndexPath indexPathForRow:[AKPUtilities readPolicy:[self validIdentifier] connection:_ctConnection success:nil] inSection:0];
	
	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStyleGrouped];
	_tableView.delegate = self;
	_tableView.dataSource = self;
	[_tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"AKPPolicyCell"];
	[_tableView setAllowsSelection:YES];
	_tableView.allowsMultipleSelection = NO;
	
	UIViewController *parentController = (UIViewController *)[self valueForKey:@"_parentController"];
	PSSpecifier *spec = [(AKPApplicationListSubcontrollerController *)parentController specifierForApplicationWithIdentifier:[self validIdentifier]];
	
	self.title = spec.name;
	self.view = _tableView;
}

@end
