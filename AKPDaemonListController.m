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

#import "AKPDaemonListController.h"
#import "AKPUtilities.h"
#import "AKPNEUtilities.h"

@implementation AKPDaemonListController

-(instancetype)init{
	if (self = [super init]){
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSpecifiers) name:FetchingDaemonsInfoFinishedNotification object:nil];
		_registry = [AKPDaemonRegistry new];
		[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
			self.policies = policies;
			dispatch_async(dispatch_get_main_queue(), ^{
				[self reloadSpecifiers];
			});
		}];
	}
	return self;
}

-(NSArray *)indexLetters{
	return @[
		@"A",
		@"B",
		@"C",
		@"D",
		@"E",
		@"F",
		@"G",
		@"H",
		@"I",
		@"J",
		@"K",
		@"L",
		@"M",
		@"N",
		@"O",
		@"P",
		@"Q",
		@"R",
		@"S",
		@"T",
		@"U",
		@"V",
		@"W",
		@"X",
		@"Y",
		@"Z",
		@"#"
	];
}

-(NSArray *)specifiers{
	if (!_specifiers){
		NSMutableArray *rootSpecifiers = [NSMutableArray array];

		if (_registry.loading){
			PSSpecifier *spinnerSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSSpinnerCell edit:nil];
			[rootSpecifiers addObject:spinnerSpec];
		}else{
			NSUInteger sectionIdx = 0;
			NSString *firstLetter;
			NSMutableDictionary *sectionIndexing = [NSMutableDictionary dictionary];
			NSMutableArray *dirtyIndexedSpecifiers = [NSMutableArray array];
			NSArray *indexLetters = [self indexLetters];
			BOOL unknownTitleSectionAdded = NO;
			for (NSDictionary *info in _registry.daemonsInfo){
				NSString *sectionTitle = [info[kBin] substringToIndex:1].uppercaseString;
				BOOL letterIsIndexed = [indexLetters containsObject:sectionTitle];
				BOOL isDirtySpecifier = NO;
				if (letterIsIndexed && ![firstLetter isEqualToString:sectionTitle]){
					firstLetter = sectionTitle;
					PSSpecifier *sectionGroupSpec = [PSSpecifier preferenceSpecifierNamed:firstLetter target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
					[rootSpecifiers addObject:sectionGroupSpec];
					sectionIndexing[firstLetter] = @(sectionIdx);
					sectionIdx++;
				}else if (!letterIsIndexed){
					unknownTitleSectionAdded = YES;
					isDirtySpecifier = YES;
					sectionIdx++;
				}
				PSSpecifier *daemonSpec = [PSSpecifier preferenceSpecifierNamed:info[kBin] target:self set:nil get:nil detail:NSClassFromString(@"AKPDaemonController") cell:PSLinkCell edit:nil];
				[daemonSpec setProperty:info forKey:@"info"];
				[daemonSpec setProperty:NSClassFromString(@"AKPDaemonListCell") forKey:@"cellClass"];
				[isDirtySpecifier ? dirtyIndexedSpecifiers : rootSpecifiers addObject:daemonSpec];
			}
			if (dirtyIndexedSpecifiers.count > 0){
				PSSpecifier *sectionGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"#" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
				[rootSpecifiers addObject:sectionGroupSpec];
				[rootSpecifiers addObjectsFromArray:dirtyIndexedSpecifiers];
				sectionIndexing[@"#"] = @(sectionIdx);
			}
			_sectionIndexByLetter = sectionIndexing.copy;
		}
		_specifiers = rootSpecifiers;
		
	}
	return _specifiers;
}

-(NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView{
	return [self indexLetters];
}

-(NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index{
	return [_sectionIndexByLetter[title] ?: @(_sectionIndexByLetter.allKeys.count) intValue];
}

-(PSSpecifier *)specifierByInfo:(NSDictionary *)info{
	for (PSSpecifier *spec in _specifiers){
		if ([[spec propertyForKey:@"info"][@"path"] isEqualToString:info[@"path"]]){
			return spec;
		}
	}
	return nil;
}

-(void)reloadSpecifierByInfo:(NSDictionary *)info animated:(BOOL)animated{
	[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
		self.policies = policies;
		dispatch_async(dispatch_get_main_queue(), ^{
			[self reloadSpecifier:[self specifierByInfo:info] animated:animated];
		});
	}];
}

-(void)viewDidLoad{
	[super viewDidLoad];
	NSString *hashedAck = [AKPUtilities hashedAck256];
	HBLogDebug(@"hashedAck: %@ ** %@", hashedAck, [AKPUtilities valueForKey:@"acknowledgedDaemonRisk" defaultValue:nil]);
	if (![[AKPUtilities valueForKey:@"acknowledgedDaemonRisk" defaultValue:nil] isEqualToString:hashedAck]){
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️⚠️⚠️ WARNING ⚠️⚠️⚠️" message:@"Any changes made in this section will NOT persist in non-jailbroken mode. However, it's highly against to do any modification for daemon. The tweak author is not responsible for any issue may or may not arise. Only proceed if you understand." preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"I Understand" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
			[AKPUtilities setValue:hashedAck forKey:@"acknowledgedDaemonRisk"];
		}];
		
		UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
			[self.navigationController popToRootViewControllerAnimated:YES];
		}];
		
		[alert addAction:yesAction];
		[alert addAction:noAction];
		
		[self presentViewController:alert animated:YES completion:nil];
	}
}

@end
