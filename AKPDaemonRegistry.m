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

#import "AKPDaemonRegistry.h"
#import "PrivateHeaders.h"
#import <mach-o/ldsyms.h>

@implementation AKPDaemonRegistry

-(instancetype)init{
	if (self = [super init]){
		dispatch_async(dispatch_get_main_queue(), ^{
			[self fetchDaemonsInfo];
		});
	}
	return self;
}

-(void)fetchDaemonsInfo{
	self.loading = YES;
	NSArray *launchServices = @[
		@"/System/Library/LaunchDaemons/",
		@"/System/Library/NanoLaunchDaemons/",
		@"/Library/LaunchDaemons/"
	];
	
	NSMutableArray *infoArray = [NSMutableArray array];
	NSMutableDictionary *uniquePathTracker = [NSMutableDictionary dictionary];
	
	for (NSString *service in launchServices){
		NSArray *daemonPlists = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:service error:nil];
		for (NSString *daemonPlist in daemonPlists){
			if ([daemonPlist.pathExtension isEqualToString:@"plist"]){
				NSString *fullPath = [NSString stringWithFormat:@"%@%@", service, daemonPlist];
				NSMutableDictionary *plist = [NSMutableDictionary dictionary];
				[plist addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:fullPath]];
				NSString *binaryPath;
				if (plist[@"Program"]) binaryPath = plist[@"Program"];
				if (binaryPath.length <= 0 && [plist[@"ProgramArguments"] count] > 0) binaryPath = [plist[@"ProgramArguments"] firstObject];
				if (binaryPath){
					if (uniquePathTracker[binaryPath]) continue;
					if ([[NSFileManager defaultManager] fileExistsAtPath:binaryPath]){
						[infoArray addObject:@{
							kLabel : plist[@"Label"], //redundant in this case
							kPath : binaryPath,
							kBin : binaryPath.lastPathComponent,
						}];
						uniquePathTracker[binaryPath] = @YES;
					}
				}
			}
		}
	}
	
#ifdef DEBUG
	[infoArray addObject:@{
		kLabel : @"com.udevs.udtool",
		kPath : @"/usr/bin/udtool",
		kBin : @"udtool",
	}];
#endif
	
	[infoArray sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:kBin ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
	
	self.daemonsInfo = infoArray.copy;
	self.loading = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:FetchingDaemonsInfoFinishedNotification object:self];
}

@end
