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

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "AKPPerAppVPNConfiguration.h"
#import "PrivateHeaders.h"

@interface PSSpecifier ()
-(void)setValues:(id)arg1 titles:(id)arg2;
@end

@interface AKPApplicationController : PSListController{
	NSString *_bundleIdentifier;
	NEConfiguration *_selectedVPNConfig;
	NSArray *_installedVPNs;
	AKPPerAppVPNConfiguration *_perAppVPNConfiguration;
	PSSpecifier *_wirelessDataSpec;
	PSSpecifier *_installedVPNsSpec;
	PSSpecifier *_perAppVPNEnabledSpec;
	PSSpecifier *_vpnDomainsSpec;
	CTServerConnectionRef _ctConnection;
	NEConfiguration *_dummyConfig;
	NSArray <NSString *> *_lastDomains;
	NSArray <NSString *> *_lastPaths;
}
-(NSArray <NSString *>*)perAppVPNDomains;
-(NSString *)perAppVPNDomainsString:(NSString *)sep;
@end
