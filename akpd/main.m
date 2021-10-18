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

#import "../Common.h"
#import <stdio.h>
#import "AKPDaemon.h"
#import "AKPDaemonDelegate.h"


int main(int argc, char *argv[], char *envp[]){

	[AKPDaemon sharedInstance];
	AKPDaemonDelegate *akpDaemon = [AKPDaemonDelegate new];
	
	NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:@"com.udevs.akpd"];
	listener.delegate = akpDaemon;
	
	[listener resume];
	dispatch_main();

	return EXIT_SUCCESS;
}
