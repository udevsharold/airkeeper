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

#import "AKPRootListController.h"
#import "AKPUtilities.h"
#import "AKPNEUtilities.h"
#import <AltList/LSApplicationProxy+AltList.h>

@implementation AKPRootListController

static void cliUpdatedPrefs(){
	[[NSNotificationCenter defaultCenter] postNotificationName:CLIUpdatedPrefsNotification object:nil];
}

-(instancetype)init{
	if (self = [super init]){
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)cliUpdatedPrefs, (CFStringRef)CLI_UPDATED_PREFS_NN, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSpecifiers) name:CLIUpdatedPrefsNotification object:nil];
	}
	return self;
}

-(void)restoringCompleted:(BOOL)completed{
	if (completed){
		_restoreSpec = [PSSpecifier preferenceSpecifierNamed:@"Restore" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[_restoreSpec setProperty:@"Restore" forKey:@"label"];
		[_restoreSpec setButtonAction:@selector(restoreAll)];
		_restoring = NO;
	}else{
		_restoreSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSSpinnerCell edit:nil];
		_restoring = YES;
	}
}

-(void)exportingCompleted:(BOOL)completed{
	if (completed){
		_exportCurrentSpec = [PSSpecifier preferenceSpecifierNamed:@"Export Current Profile" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[_exportCurrentSpec setProperty:@"Export Current Settings" forKey:@"label"];
		[_exportCurrentSpec setButtonAction:@selector(exportCurrentSettings)];
		_exporting = NO;
	}else{
		_exportCurrentSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSSpinnerCell edit:nil];
		_exporting = YES;
	}
}

-(void)importingCompleted:(BOOL)completed{
	if (completed){
		_importSpec = [PSSpecifier preferenceSpecifierNamed:@"Import Profile" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[_importSpec setProperty:@"Import Settings" forKey:@"label"];
		[_importSpec setButtonAction:@selector(importSettings)];
		_importing = NO;
	}else{
		_importSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSSpinnerCell edit:nil];
		_importing = YES;
	}
}

-(void)dealloc{
	if (_ctConnection) CFRelease(_ctConnection);
}

-(void)viewDidLoad{
	[super viewDidLoad];
	
	CGRect frame = CGRectMake(0,0,self.table.bounds.size.width,170);
	CGRect Imageframe = CGRectMake(0,10,self.table.bounds.size.width,80);
	
	
	UIView *headerView = [[UIView alloc] initWithFrame:frame];
	headerView.backgroundColor = [UIColor colorWithRed: 0.40 green: 0.60 blue: 0.20 alpha: 1.00];
	
	UIImage *headerImage = [[UIImage alloc]
							initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/AirKeeper.bundle"] pathForResource:@"AirKeeper512" ofType:@"png"]];
	UIImageView *imageView = [[UIImageView alloc] initWithFrame:Imageframe];
	[imageView setImage:headerImage];
	[imageView setContentMode:UIViewContentModeScaleAspectFit];
	[imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
	[headerView addSubview:imageView];
	
	CGRect labelFrame = CGRectMake(0,imageView.frame.origin.y + 90 ,self.table.bounds.size.width,80);
	UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:40];
	UILabel *headerLabel = [[UILabel alloc] initWithFrame:labelFrame];
	[headerLabel setText:@"AirKeeper"];
	[headerLabel setFont:font];
	[headerLabel setTextColor:[UIColor blackColor]];
	headerLabel.textAlignment = NSTextAlignmentCenter;
	[headerLabel setContentMode:UIViewContentModeScaleAspectFit];
	[headerLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
	[headerView addSubview:headerLabel];
	
	self.table.tableHeaderView = headerView;
}

- (NSArray *)specifiers{
	if (!_specifiers) {
		NSMutableArray *rootSpecifiers = [[NSMutableArray alloc] init];
		
		//Manage (Non-persistent)
		PSSpecifier *manageNonPersistentGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Manage (Non-persistent)" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:manageNonPersistentGroupSpec];
		
		//Globals
		PSSpecifier *globalSpec = [PSSpecifier preferenceSpecifierNamed:@"Globals" target:nil set:nil get:nil detail:NSClassFromString(@"AKPDaemonGlobalController") cell:PSLinkCell edit:nil];
		[globalSpec setProperty:@{
			@"label" : @"global"
		} forKey:@"info"];
		[rootSpecifiers addObject:globalSpec];
		
		//Apps
		PSSpecifier *altListNonPersistSpec = [PSSpecifier preferenceSpecifierNamed:@"Applications" target:nil set:nil get:nil detail:NSClassFromString(@"AKPDaemonApplicationListSubcontrollerController") cell:PSLinkListCell edit:nil];
		[altListNonPersistSpec setProperty:@"AKPDaemonController" forKey:@"subcontrollerClass"];
		[altListNonPersistSpec setProperty:@"Applications" forKey:@"label"];
		[altListNonPersistSpec setProperty:@[
			@{@"sectionType":@"All"},
		] forKey:@"sections"];
		[altListNonPersistSpec setProperty:@YES forKey:@"useSearchBar"];
		[altListNonPersistSpec setProperty:@YES forKey:@"hideSearchBarWhileScrolling"];
		[altListNonPersistSpec setProperty:@YES forKey:@"alphabeticIndexingEnabled"];
		[altListNonPersistSpec setProperty:@YES forKey:@"showIdentifiersAsSubtitle"];
		[rootSpecifiers addObject:altListNonPersistSpec];
		
		//Daemons
		PSSpecifier *daemonsSpec = [PSSpecifier preferenceSpecifierNamed:@"Daemons" target:nil set:nil get:nil detail:NSClassFromString(@"AKPDaemonListController") cell:PSLinkCell edit:nil];
		[rootSpecifiers addObject:daemonsSpec];
		
		
		//Manage (Persistent)
		PSSpecifier *manageGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Manage (Persistent)" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:manageGroupSpec];
		
		//Apps
		PSSpecifier *altListSpec = [PSSpecifier preferenceSpecifierNamed:@"Applications" target:nil set:nil get:nil detail:NSClassFromString(@"AKPApplicationListSubcontrollerController") cell:PSLinkListCell edit:nil];
		[altListSpec setProperty:@"AKPApplicationController" forKey:@"subcontrollerClass"];
		[altListSpec setProperty:@"Applications" forKey:@"label"];
		[altListSpec setProperty:@[
			@{@"sectionType":@"Visible"},
		] forKey:@"sections"];
		[altListSpec setProperty:@YES forKey:@"useSearchBar"];
		[altListSpec setProperty:@YES forKey:@"hideSearchBarWhileScrolling"];
		[altListSpec setProperty:@YES forKey:@"alphabeticIndexingEnabled"];
		[altListSpec setProperty:@YES forKey:@"showIdentifiersAsSubtitle"];
		[rootSpecifiers addObject:altListSpec];
		
		
		//settings
		PSSpecifier *settingsGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Profiles" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:settingsGroupSpec];
		
		//export
		[self exportingCompleted:!_exporting];
		[rootSpecifiers addObject:_exportCurrentSpec];
		
		//import
		[self importingCompleted:!_importing];
		[rootSpecifiers addObject:_importSpec];
		
		
		//reset
		PSSpecifier *restoreGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:restoreGroupSpec];
		
		[self restoringCompleted:!_restoring];
		[rootSpecifiers addObject:_restoreSpec];
		
		//reboot daemon
		PSSpecifier *knockGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[knockGroupSpec setProperty:@"Reinitialize AirKeeper, not usually required, unless some daemons' binary identification were updated." forKey:@"footerText"];
		[rootSpecifiers addObject:knockGroupSpec];
		
		PSSpecifier *knockSpec = [PSSpecifier preferenceSpecifierNamed:@"Reboot AirKeeper" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[knockSpec setProperty:@"Reboot AirKeeper" forKey:@"label"];
		[knockSpec setButtonAction:@selector(knockAirKeeper)];
		[rootSpecifiers addObject:knockSpec];
		
		
#ifdef DEBUG
		//DEBUG
		PSSpecifier *debugGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:debugGroupSpec];
		
		PSSpecifier *debugSpec = [PSSpecifier preferenceSpecifierNamed:@"DEBUG" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[debugSpec setProperty:@"DEBUG" forKey:@"label"];
		[debugSpec setButtonAction:@selector(doDebug)];
		[rootSpecifiers addObject:debugSpec];
#endif
		
		//notice group
		PSSpecifier *noticeSpecGroup = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[noticeSpecGroup setProperty:@"Persistent mode will effectively writes to /var/preferences/com.apple.networkextension.plist. Either uninstalling this tweak, using the \"Restore\" button above, or delete the file (and userspace reboot) will revert all changes made. The file store some other configurations, like VPN profiles. This tweak works on both iPhone and iPad (Wi-Fi/Cellular)." forKey:@"footerText"];
		[rootSpecifiers addObject:noticeSpecGroup];
		
		//blsnk group
		PSSpecifier *blankSpecGroup = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:blankSpecGroup];
		
		//Support Dev
		PSSpecifier *supportDevGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Development" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:supportDevGroupSpec];
		
		PSSpecifier *supportDevSpec = [PSSpecifier preferenceSpecifierNamed:@"Support Development" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[supportDevSpec setProperty:@"Support Development" forKey:@"label"];
		[supportDevSpec setButtonAction:@selector(donation)];
		[supportDevSpec setProperty:[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/AirKeeper.bundle/PayPal.png"] forKey:@"iconImage"];
		[rootSpecifiers addObject:supportDevSpec];
		
		
		//Contact
		PSSpecifier *contactGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Contact" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[rootSpecifiers addObject:contactGroupSpec];
		
		//Twitter
		PSSpecifier *twitterSpec = [PSSpecifier preferenceSpecifierNamed:@"Twitter" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[twitterSpec setProperty:@"Twitter" forKey:@"label"];
		[twitterSpec setButtonAction:@selector(twitter)];
		[twitterSpec setProperty:[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/AirKeeper.bundle/Twitter.png"] forKey:@"iconImage"];
		[rootSpecifiers addObject:twitterSpec];
		
		//Reddit
		PSSpecifier *redditSpec = [PSSpecifier preferenceSpecifierNamed:@"Reddit" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
		[redditSpec setProperty:@"Twitter" forKey:@"label"];
		[redditSpec setButtonAction:@selector(reddit)];
		[redditSpec setProperty:[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/AirKeeper.bundle/Reddit.png"] forKey:@"iconImage"];
		[rootSpecifiers addObject:redditSpec];
		
		//udevs
		PSSpecifier *createdByGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
		[createdByGroupSpec setProperty:@"Created by udevs" forKey:@"footerText"];
		[createdByGroupSpec setProperty:@1 forKey:@"footerAlignment"];
		[rootSpecifiers addObject:createdByGroupSpec];
		
		_specifiers = rootSpecifiers;
	}
	
	return _specifiers;
}

-(void)donation{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.me/udevs"] options:@{} completionHandler:nil];
}

-(void)twitter{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/udevs9"] options:@{} completionHandler:nil];
}

-(void)reddit{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.reddit.com/user/h4roldj"] options:@{} completionHandler:nil];
}

-(CTServerConnectionRef)ctConnection{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_ctConnection  = [AKPUtilities ctConnection];
	});
	return _ctConnection;
}

-(void)popConfirmationAlertWithTitle:(NSString *)title message:(NSString *)message onConfirm:(dispatch_block_t)confirmHandler onCancel:(dispatch_block_t)cancelHandler{
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
		if (confirmHandler) confirmHandler();
	}]];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
		if (cancelHandler) cancelHandler();
	}]];
	
	[self presentViewController:alert animated:YES completion:nil];
}

-(void)restoreAll{
	
	void (^startSpinSpecifier)(BOOL) = ^(BOOL spin){
		[self restoringCompleted:!spin];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self reloadSpecifiers];
		});
	};
	
	
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restore" message:nil preferredStyle:UIAlertControllerStyleAlert];
	
	//Connectivity
	[alert addAction:[UIAlertAction actionWithTitle:@"Restore Connectivity" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
		[self popConfirmationAlertWithTitle:@"Restore Connectivity" message:@"Restore all made changes back to \"Wi-Fi & Mobile Data\"?" onConfirm:^{
			self.view.userInteractionEnabled = NO;
			startSpinSpecifier(YES);
			//[AKPUtilities restoreAllChanged:[self ctConnection]];
			[AKPUtilities purgeCellularUsagePolicyWithHandler:^(NSArray <NSError *>*errors){
				[AKPUtilities removeKey:@"daemonTamingValue"];
				[AKPNEUtilities initializeSessionAndWait:NO reply:^(NSError *error){
					startSpinSpecifier(NO);
				}];
			}];
			self.view.userInteractionEnabled = YES;
		} onCancel:^{
			
		}];
	}]];
	
	//VPNs
	[alert addAction:[UIAlertAction actionWithTitle:@"Restore Per App VPNs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
		[self popConfirmationAlertWithTitle:@"Restore Per App VPNs" message:@"Restore all created per app VPN profiles?" onConfirm:^{
			self.view.userInteractionEnabled = NO;
			startSpinSpecifier(YES);
			[AKPUtilities purgeCreatedNetworkConfigurationForPerAppWithHandler:^(NSArray <NSError *>*errors){
				startSpinSpecifier(NO);
			}];
			self.view.userInteractionEnabled = YES;
		} onCancel:^{
			
		}];
	}]];
	
	//All
	[alert addAction:[UIAlertAction actionWithTitle:@"Restore All" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
		[self popConfirmationAlertWithTitle:@"Restore All" message:@"Restore all made changes?" onConfirm:^{
			self.view.userInteractionEnabled = NO;
			startSpinSpecifier(YES);
			[AKPUtilities restoreAllConfigurationsAndWaitInitialize:YES handler:^(NSArray <NSError *>*errors){
				startSpinSpecifier(NO);
			}];
			self.view.userInteractionEnabled = YES;
		} onCancel:^{
			
		}];
	}]];
	
	//Restore and Reset cache
	[alert addAction:[UIAlertAction actionWithTitle:@"Restore & Reset" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
		[self popConfirmationAlertWithTitle:@"Restore & Reset" message:@"Restore and reset all made changes and cache?" onConfirm:^{
			self.view.userInteractionEnabled = NO;
			startSpinSpecifier(YES);
			[[NSFileManager defaultManager] removeItemAtPath:PREFS_PATH error:nil];
			[AKPUtilities restoreAllConfigurationsAndWaitInitialize:YES handler:^(NSArray <NSError *>*errors){
				startSpinSpecifier(NO);
			}];
			self.view.userInteractionEnabled = YES;
		} onCancel:^{
			
		}];
	}]];
	
	//Cancel
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
	}]];
	
	[self presentViewController:alert animated:YES completion:nil];
}

-(NSArray *)exportedSettingFiles{
	NSMutableArray *files = [NSMutableArray array];
	NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:SETTINGS_BACKUP_PATH error:nil];
	for (NSString *file in contents){
		if ([file.pathExtension isEqualToString:@"plist"] && [file hasPrefix:SETTINGS_BACKUP_FILE_PREFIX]){
			[files addObject:file];
		}
	}
	NSSortDescriptor* sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(localizedCompare:)];
	return [files sortedArrayUsingDescriptors:@[sortDescriptor]];
}

-(void)exportCurrentSettings{
	
	void (^startSpinSpecifier)(BOOL) = ^(BOOL spin){
		[self exportingCompleted:!spin];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self reloadSpecifiers];
		});
	};
	
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export Profile" message:@"Profile name:" preferredStyle:UIAlertControllerStyleAlert];
	[alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField){
		NSArray *files = [self exportedSettingFiles];
		textField.text = [NSString stringWithFormat:@"Profile%02lu", files.count + 1];
		textField.placeholder = @"Profile Name";
		textField.secureTextEntry = NO;
	}];
	UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Export" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
		startSpinSpecifier(YES);
		[AKPUtilities exportProfileTo:[NSString stringWithFormat:@"%@%@%@.plist", SETTINGS_BACKUP_PATH, SETTINGS_BACKUP_FILE_PREFIX, [[alert textFields][0] text]] connection:[self ctConnection] handler:^(NSData *exportedData, NSArray <NSError *>*errors){
			startSpinSpecifier(NO);
		}];
	}];
	
	UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
	}];
	
	[alert addAction:yesAction];
	[alert addAction:noAction];
	
	[[NSFileManager defaultManager] createDirectoryAtPath:SETTINGS_BACKUP_PATH withIntermediateDirectories:YES attributes:nil error:nil];
	[self presentViewController:alert animated:YES completion:nil];
}

-(void)importSettings{
	
	void (^startSpinSpecifier)(BOOL) = ^(BOOL spin){
		[self importingCompleted:!spin];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self reloadSpecifiers];
		});
	};
	
	NSArray *files = [self exportedSettingFiles];
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Profile" message:(files.count > 0 ? @"Select profile:" : @"No profile available.") preferredStyle:UIAlertControllerStyleAlert];
	
	for (NSString *file in files){
		UIAlertAction *fileAction = [UIAlertAction actionWithTitle:[file.stringByDeletingPathExtension.lastPathComponent substringFromIndex:[SETTINGS_BACKUP_FILE_PREFIX length]] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
			startSpinSpecifier(YES);
			NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@%@", SETTINGS_BACKUP_PATH, file]];
			NSDictionary *profile = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			[AKPUtilities completeProfileImport:profile connection:[self ctConnection] waitInitialize:NO handler:^(NSArray <NSError *>*errors){
				startSpinSpecifier(NO);
			}];
		}];
		[alert addAction:fileAction];
	}
	
	UIAlertAction *noAction = [UIAlertAction actionWithTitle:(files.count > 0 ? @"Cancel" : @"OK") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
	}];
	
	[alert addAction:noAction];
	
	[self presentViewController:alert animated:YES completion:nil];
}

-(void)knockAirKeeper{
	[AKPNEUtilities initializeSessionAndWait:NO reply:^(NSError *error){
		
	}];
}

#ifdef DEBUG
-(void)doDebug{
	[AKPUtilities completeProfileExport:[self ctConnection] handler:^(NSDictionary *exportedProfile, NSArray <NSError *>*errors){
		HBLogDebug(@"exportedProfile: %@", exportedProfile);
		[AKPUtilities completeProfileImport:exportedProfile connection:[self ctConnection] waitInitialize:YES handler:^(NSArray <NSError *>*errors){
			HBLogDebug(@"import erors: %@", errors);
		}];
	}];
}
#endif
@end
