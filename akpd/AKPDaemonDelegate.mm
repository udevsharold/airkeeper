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

#import "AKPDaemonDelegate.h"
#import "AKPDaemon.h"
#import "AKPPolicyControlling-Protocol.h"
#import <xpc/xpc.h>

@implementation AKPDaemonDelegate
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
		
	//Make sure only entitled process can set policy (us)
	xpc_object_t ent = xpc_connection_copy_entitlement_value([newConnection _xpcConnection], "application-identifier");
	BOOL isEntitled = [[newConnection valueForEntitlement:@"com.udevs.akpd.xpc"] boolValue] ||
	(ent && xpc_get_type(ent) == XPC_TYPE_STRING && strcmp(xpc_string_get_string_ptr(ent), "com.apple.Preferences") == 0);
	
	if (!isEntitled){
		HBLogDebug(@"XPC cnx has no valid entitlement.");
		return NO;
	}
	
	newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AKPPolicyControlling)];

	AKPDaemon *akpDaemon = [AKPDaemon sharedInstance];
	
	//Keep alive
	NSFileManager *fm = [NSFileManager defaultManager];
	if (!akpDaemon.initialized && ![fm fileExistsAtPath:KEEP_ALIVE_FILE]){
		[fm createDirectoryAtPath:KEEP_ALIVE_FILE.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
		[fm createFileAtPath:KEEP_ALIVE_FILE contents:[@"" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
	}
	
	//Shut down daemon when no longer needed to prevent unnecessary memory usage
	[akpDaemon queueTerminationIfNecessaryWithDelay:120.0];
	
	newConnection.exportedObject = akpDaemon;
	[newConnection resume];
	
	return YES;
}
@end
