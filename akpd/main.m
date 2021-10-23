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
#import <sys/kern_memorystatus.h>
#import <libproc/libproc_internal.h>

int main(int argc, char *argv[], char *envp[]){
	
	pid_t pid = getpid();
	
	//increase jetsam memory usage
	memorystatus_memlimit_properties_t mem_props;
	mem_props.memlimit_active = 100;
	mem_props.memlimit_active_attr &= ~(uint32_t)MEMORYSTATUS_MEMLIMIT_ATTR_FATAL;
	mem_props.memlimit_inactive = 100;
	mem_props.memlimit_inactive_attr &= ~(uint32_t)MEMORYSTATUS_MEMLIMIT_ATTR_FATAL;
	memorystatus_control(MEMORYSTATUS_CMD_SET_MEMLIMIT_PROPERTIES, pid, 0, &mem_props, sizeof(mem_props));
	
	memorystatus_priority_properties_t mem_prio;
	mem_prio.priority = JETSAM_PRIORITY_BACKGROUND;
	memorystatus_control(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, pid, 0, &mem_prio, sizeof(mem_prio));
	
	//disable violation of cpu limits over time
	proc_disable_cpumon(pid);
	
	AKPDaemon *akpDaemon = [AKPDaemon sharedInstance];
	[akpDaemon initializeSessionAndWait:NO reply:^(NSError *error){
	}];
	
	AKPDaemonDelegate *akpDaemonDelegate = [AKPDaemonDelegate new];
	
	NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:@"com.udevs.akpd"];
	listener.delegate = akpDaemonDelegate;
	
	[listener resume];
	dispatch_main();
	
	return EXIT_SUCCESS;
}
