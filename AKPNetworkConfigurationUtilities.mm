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
#import "AKPNetworkConfigurationUtilities.h"

@implementation AKPNetworkConfigurationUtilities

+(dispatch_queue_t)_aptQueue{
	static dispatch_once_t once;
	static dispatch_queue_t queue;
	dispatch_once(&once, ^{
		SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
		CFStringRef value = (CFStringRef)SecTaskCopyValueForEntitlement(task, CFSTR("application-identifier"), NULL);
		if (value && CFGetTypeID(value) != CFStringGetTypeID()){
			CFRelease(value);
			value = NULL;
		}
		if (STRMATCH(value, CFSTR("com.udevs.akp"))){
			queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
		}else{
			queue = dispatch_get_main_queue();
		}
		if (task) CFRelease(task);
	});
	return queue;
}

+(void)loadConfigurationsWithCompletion:(void (^)(NSArray * configurations, NSError * error))handler{
	[[NEConfigurationManager sharedManagerForAllUsers] loadConfigurationsWithCompletionQueue:[AKPNetworkConfigurationUtilities _aptQueue] handler:^(NSArray *configurations, NSError *error){
		HBLogDebug(@"loadConfigurationsWithCompletion: %@", error);
		if (handler) handler(configurations, error);
	}];
}

+(void)saveConfiguration:(NEConfiguration *)neConfig handler:(void(^)(NSError * error))handler{
	[[NEConfigurationManager sharedManagerForAllUsers] saveConfiguration:neConfig withCompletionQueue:[AKPNetworkConfigurationUtilities _aptQueue] handler:^(NSError *error){
		HBLogDebug(@"saveConfiguration: %@", error);
		if (handler) handler(error);
	}];
}

+(void)removeConfiguration:(NEConfiguration *)configuration handler:(void (^)(NSError *error))handler{
	[[NEConfigurationManager sharedManagerForAllUsers] removeConfiguration:configuration withCompletionQueue:[AKPNetworkConfigurationUtilities _aptQueue] handler:^(NSError *error){
		HBLogDebug(@"removeConfiguration: %@", error);
		if (handler) handler(error);
	}];
}
@end
