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

#import <stdio.h>
#import <getopt.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "../Common.h"
#import "../AKPUtilities.h"
#import <AltList/LSApplicationProxy+AltList.h>

#define CFRELASE_AND_RETURN(code) if (ctConnection) CFRelease(ctConnection); return code;

static LSApplicationProxy* appproxy_from_bundle_identifier(NSString *identifier){
	return [objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:identifier];
}

static void print_help(){
	fprintf(stdout,
			"Usage: akp [options] IDENTIFIER\n"
			"       options:\n"
			"           -p, --policy <0..3>:\n"
			"               0 - Off\n"
			"               1 - Mobile Data\n"
			"               2 - Wi-Fi\n"
			"               3 - Wi-Fi & Mobile Data\n"
			"           -r, --restore: restore all changed policies\n"
			"           -F, --policyforce <0..3>: set policy for all available bundles, use with care\n"
			"           -e, --export <file path>: export policies\n"
			"           -i, --import <file path>: import policies\n"
			"           -l, --list: list all changed policies\n"
			"           -h, --help: help\n"
			);
	exit(-1);
}


int main(int argc, char *argv[], char *envp[]) {
	
	static struct option longopts[] = {
		{ "policy", required_argument, 0, 'p' },
		{ "policyforce", required_argument, 0, 'F' },
		{ "restore", no_argument, 0, 'r' },
		{ "export", required_argument, 0, 'e' },
		{ "import", required_argument, 0, 'i' },
		{ "list", no_argument, 0, 'l' },
		{ "help", no_argument, 0, 'h'},
		{ 0, 0, 0, 0 }
	};
	
	CTServerConnectionRef ctConnection  = [AKPUtilities ctConnection];
	BOOL setPolicy = NO;
	BOOL setPolicyForced = NO;
	AKPPolicyType type = AKPPolicyTypeAllAllow;
	
	int opt;
	while ((opt = getopt_long(argc, argv, "p:F:re:i:lh", longopts, NULL)) != -1){
		switch (opt){
			case 'p':
				setPolicy = YES;
				type = [@(optarg) intValue];
				break;
			case 'F':
				setPolicyForced = YES;
				type = [@(optarg) intValue];
				break;
			case 'r':{
				[AKPUtilities restoreAllChanged:ctConnection];
				CFRELASE_AND_RETURN(0);
			}
			case 'e':{
				NSString *file = @(optarg);
				if (access(file.stringByDeletingLastPathComponent.UTF8String, W_OK) == 0){
					[AKPUtilities exportPoliciesTo:file connection:ctConnection];
				}else{
					fprintf(stderr, "ERROR: %s is not writable, check permission!\n", optarg);
					CFRELASE_AND_RETURN(1);
				}
				CFRELASE_AND_RETURN(0);
			}
			case 'i':{
				NSString *file = @(optarg);
				if (access(file.stringByDeletingLastPathComponent.UTF8String, R_OK) == 0){
					NSDictionary *policies = [[NSDictionary alloc] initWithContentsOfFile:file];
					return ![AKPUtilities importPolicies:policies connection:ctConnection];
				}else{
					fprintf(stderr, "ERROR: %s is not readable, check permission!\n", optarg);
					CFRELASE_AND_RETURN(1);
				}
			}
			case 'l':{
				NSDictionary *policies = [AKPUtilities exportPolicies:ctConnection];
				for (NSString *identifier in policies.allKeys){
					fprintf(stdout, "%s - %s\n", identifier.UTF8String, [AKPUtilities stringForPolicy:[policies[identifier] intValue]].UTF8String);
				}
				CFRELASE_AND_RETURN(0);
			}
			default:
				print_help();
				break;
		}
	}
	
	argc -= optind;
	argv += optind;
	
	if (argc < 1 && !setPolicyForced) {fprintf(stderr, "ERROR: IDENTIFIER not specified!\n"); return -1;}
	if (!setPolicyForced && !appproxy_from_bundle_identifier(@(argv[0])).bundleURL) {fprintf(stderr, "ERROR: IDENTIFIER not valid!\n"); CFRELASE_AND_RETURN(1);}
	
	BOOL success = NO;
	if (ctConnection){
		if (setPolicy){
			setPolicyForced ? [AKPUtilities setPolicyForAll:type connection:ctConnection success:&success] : [AKPUtilities setPolicy:type forIdentifier:@(argv[0]) connection:ctConnection success:&success];
			if (success){
				fprintf(stdout, "Policy set to \"%s\"\n", [AKPUtilities stringForPolicy:type].UTF8String);
			}else{
				fprintf(stderr, "ERROR: Unable to set policy for %s!\n", argv[0]);
			}
		}else{
			NSString *currentPolicy = [AKPUtilities policyAsString:@(argv[0]) connection:ctConnection success:&success];
			if (success){
				fprintf(stdout, "%s\n",  currentPolicy.UTF8String);
			}else{
				fprintf(stderr, "ERROR: Unable to get policy for %s!\n", argv[0]);
			}
		}
	}else{
		fprintf(stderr, "ERROR: Failed to initialize!\n");
		CFRELASE_AND_RETURN(1);
	}
	CFRELASE_AND_RETURN(0);
}
