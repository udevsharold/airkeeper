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
#import "../AKPNEUtilities.h"
#import <AltList/LSApplicationProxy+AltList.h>
#import "../PrivateHeaders.h"

#define CFRELASE_AND_RETURN(code) if (ctConnection) CFRelease(ctConnection); return code;
#define TIMEOUT 15.0
#define SEMA_TIMEOUT(sema, s) dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(s * NSEC_PER_SEC)));

typedef NS_ENUM(NSInteger, OPTEXTRAS){
	RULE,
	DIRECTION,
	PRIMUS_RULE,
	SECUNDAS_RULE,
	TERTIUS_RULE
};

static LSApplicationProxy* appproxy_from_bundle_identifier(NSString *identifier){
	return [objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:identifier];
}

static void print_help(){
	fprintf(stdout,
			"Usage: akp [options] IDENTIFIER|PATH\n"
			"	options:\n"
			"		-P, --persist: persistent mode\n"
			"		-p, --policy <0..3>:\n"
			"			0 - Off\n"
			"			1 - Mobile Data\n"
			"			2 - Wi-Fi\n"
			"			3 - Wi-Fi & Mobile Data\n"
			"		-r, --restore: restore all changed policies\n"
			"		-F, --policyforce <0..3>: set policy for all available bundles, use with care\n"
			"		-a, --app: enter app mode (default)\n"
			"		-d, --daemon: enter daemon mode\n"
			"		-g, --global: enter global mode\n"
			"		--rule: <0..2>: rule\n"
			"			0 - Pass\n"
			"			1 - Block\n"
			"			2 - Allow\n"
			"		--primaryrule <0...2>: primary rule\n"
			"		--secondaryrule <0...2>: secondary rule\n"
			"		--direction <0..2>: traffic direction\n"
			"			0 - Pass\n"
			"			1 - Inbound Only\n"
			"			2 - Outbound Only\n"
			"		-e, --export <file path>: export profile\n"
			"		-i, --import <file path>: import profile\n"
			"		-l, --list: list all changed policies\n"
			"		-h, --help: help\n"
			);
	exit(-1);
}


int main(int argc, char *argv[], char *envp[]) {
	
	static struct option longopts[] = {
		{ "app", no_argument, 0, 'a' },
		{ "daemon", no_argument, 0, 'd' },
		{ "global", no_argument, 0, 'g' },
		{ "rule", required_argument, 0, RULE },
		{ "direction", required_argument, 0, DIRECTION },
		{ "primaryrule", required_argument, 0, PRIMUS_RULE },
		{ "secondaryrule", required_argument, 0, SECUNDAS_RULE },
		{ "persist", no_argument, 0, 'P' },
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
	BOOL daemonMode = NO;
	BOOL globalMode = NO;
	BOOL appMode = YES;
	BOOL list = NO;
	AKPDaemonTrafficRule primusRule = AKPDaemonTrafficRuleUnknown;
	AKPDaemonTrafficRule secundasRule = AKPDaemonTrafficRuleUnknown;
	AKPDaemonTrafficRule tertiusRule = AKPDaemonTrafficRuleUnknown;
	AKPPolicyMode mode = AKPPolicyModeNonPersist;
	AKPPolicyType type = AKPPolicyTypeUnknown;
	
	int opt;
	while ((opt = getopt_long(argc, argv, "adgPp:F:re:i:lh", longopts, NULL)) != -1){
		switch (opt){
			case 'd':
				daemonMode = YES;
				break;
			case 'g':
				globalMode = YES;
				break;
			case 'a':
				appMode = YES; //for the sake of false sense (-a is default)
				break;
			case PRIMUS_RULE:{
				setPolicy = YES;
				primusRule = [@(optarg) intValue];
				if (primusRule > AKPDaemonTrafficRulePassDomain || primusRule < AKPDaemonTrafficRulePassAllDomains){
					primusRule = AKPDaemonTrafficRulePassAllDomains;
				}
				break;
			}
			case RULE:
			case SECUNDAS_RULE:{
				setPolicy = YES;
				secundasRule = [@(optarg) intValue];
				if (secundasRule > AKPDaemonTrafficRulePassDomain || secundasRule < AKPDaemonTrafficRulePassAllDomains){
					secundasRule = AKPDaemonTrafficRulePassAllDomains;
				}
				break;
			}
			case DIRECTION:{
				setPolicy = YES;
				tertiusRule = [@(optarg) intValue];
				switch (tertiusRule){
					case 1:
						tertiusRule = AKPDaemonTrafficRuleDropOutbound;
						break;
					case 2:
						tertiusRule = AKPDaemonTrafficRuleDropInbound;
						break;
					case 0:
					default:
						tertiusRule = AKPDaemonTrafficRulePassAllBounds;
						break;
				}
				break;
			}
			case TERTIUS_RULE:{
				setPolicy = YES;
				tertiusRule = [@(optarg) intValue];
				if (tertiusRule > AKPDaemonTrafficRulePassDomain || tertiusRule < AKPDaemonTrafficRulePassAllDomains){
					tertiusRule = AKPDaemonTrafficRulePassAllDomains;
				}
				break;
			}
			case 'P':
				mode = AKPPolicyModePersist;
				break;
			case 'F':
				setPolicy = YES;
				setPolicyForced = YES;
				type = [@(optarg) intValue];
				if (type > AKPPolicyTypeAllAllow || type < AKPPolicyTypeNone){
					type = AKPPolicyTypeAllAllow;
				}
				break;
			case 'p':
				setPolicy = YES;
				type = [@(optarg) intValue];
				if (type > AKPPolicyTypeAllAllow || type < AKPPolicyTypeNone){
					type = AKPPolicyTypeAllAllow;
				}
				break;
			case 'r':{
				dispatch_semaphore_t sema = dispatch_semaphore_create(0);
				[AKPUtilities restoreAllConfigurationsWithHandler:^(NSArray <NSError *>* errors){
					dispatch_semaphore_signal(sema);
				}];
				SEMA_TIMEOUT(sema, TIMEOUT);
				CFRELASE_AND_RETURN(0);
			}
			case 'e':{
				NSString *file = @(optarg);
				if (access(file.stringByDeletingLastPathComponent.UTF8String, W_OK) == 0){
					dispatch_semaphore_t sema = dispatch_semaphore_create(0);
					[AKPUtilities exportProfileTo:file connection:ctConnection handler:^(NSData *exportedData, NSArray <NSError *>*errors){
						dispatch_semaphore_signal(sema);
					}];
					SEMA_TIMEOUT(sema, TIMEOUT);
				}else{
					fprintf(stderr, "ERROR: %s is not writable, check permission!\n", optarg);
					CFRELASE_AND_RETURN(1);
				}
				CFRELASE_AND_RETURN(0);
			}
			case 'i':{
				NSString *file = @(optarg);
				if (access(file.stringByDeletingLastPathComponent.UTF8String, R_OK) == 0){
					NSData *data = [NSData dataWithContentsOfFile:file];
					NSDictionary *profile = [NSKeyedUnarchiver unarchiveObjectWithData:data];
					dispatch_semaphore_t sema = dispatch_semaphore_create(0);
					[AKPUtilities completeProfileImport:profile connection:ctConnection handler:^(NSArray <NSError *>*errors){
						dispatch_semaphore_signal(sema);
					}];
					SEMA_TIMEOUT(sema, TIMEOUT);
				}else{
					fprintf(stderr, "ERROR: %s is not readable, check permission!\n", optarg);
					CFRELASE_AND_RETURN(1);
				}
				CFRELASE_AND_RETURN(0);
			}
			case 'l':{
				list = YES;
				break;
			}
			default:
				print_help();
				break;
		}
	}
	
	argc -= optind;
	argv += optind;
	
	if (list){
		if (mode == AKPPolicyModePersist){
			NSDictionary *policies = [AKPUtilities exportPolicies:ctConnection];
			for (NSString *identifier in policies.allKeys){
				fprintf(stdout, "%s - %s\n", identifier.UTF8String, [AKPUtilities stringForPolicy:[policies[identifier] intValue]].UTF8String);
			}
		}else if (mode == AKPPolicyModeNonPersist){
			dispatch_semaphore_t sema = dispatch_semaphore_create(0);
			[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
				for (NSString *identifier in policies.allKeys){
					fprintf(stdout, "%s - %s\n", identifier.UTF8String, [AKPUtilities stringForPolicy:[policies[identifier][kPolicy] intValue]].UTF8String);
				}
				dispatch_semaphore_signal(sema);
			}];
			SEMA_TIMEOUT(sema, TIMEOUT);
		}
		CFRELASE_AND_RETURN(0);
	}
	
	
	if (argc < 1 && !setPolicyForced && !globalMode) {fprintf(stderr, "ERROR: IDENTIFIER not specified!\n"); return -1;}
	if (!daemonMode && !globalMode && !setPolicyForced && !appproxy_from_bundle_identifier(@(argv[0])).bundleURL) {fprintf(stderr, "ERROR: IDENTIFIER not valid!\n"); CFRELASE_AND_RETURN(1);}
	if (daemonMode && access(argv[0], R_OK) != 0) {fprintf(stderr, "ERROR: PATH not valid!\n"); CFRELASE_AND_RETURN(1);}
	if (setPolicyForced && (daemonMode || globalMode)) {fprintf(stderr, "ERROR: -dg not compatible with -F\n"); CFRELASE_AND_RETURN(1);}
	
	if (globalMode){
		dispatch_semaphore_t sema = dispatch_semaphore_create(0);
		[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
			NSMutableDictionary *policy = [policies[kGlobal] ?: @{} mutableCopy];
			
			if (primusRule != AKPDaemonTrafficRuleUnknown){
				NSDictionary *newParams = @{
					kPolicingOrder : @(AKPPolicingOrderGlobal),
					kLabel : kGlobal,
					kPrimusRule : @(primusRule)
				};
				[policy addEntriesFromDictionary:newParams];
			}
			if (secundasRule != AKPDaemonTrafficRuleUnknown){
				NSDictionary *newParams = @{
					kPolicingOrder : @(AKPPolicingOrderGlobal),
					kLabel : kGlobal,
					kSecundasRule : @(secundasRule)
				};
				[policy addEntriesFromDictionary:newParams];
			}
			NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
			[AKPUtilities setDaemonTamingValue:cleansedPolicy forKey:kGlobal];
			[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
				if (error){
					fprintf(stderr, "ERROR: Unable to set policy for global!\n");
				}else{
					fprintf(stdout, "Policy set for global (NON-PERSISTENT)\n");
				}
				dispatch_semaphore_signal(sema);
			}];
		}];
		SEMA_TIMEOUT(sema, TIMEOUT);
		CFRELASE_AND_RETURN(0);
	}
	
	BOOL success = NO;
	if (mode == AKPPolicyModePersist){
		if (ctConnection){
			if (setPolicy && type != AKPPolicyTypeUnknown){
				setPolicyForced ? [AKPUtilities setPolicyForAll:type connection:ctConnection success:&success] : [AKPUtilities setPolicy:type forIdentifier:@(argv[0]) connection:ctConnection success:&success];
				if (success){
					fprintf(stdout, "Policy set to \"%s\" (PERSISTENT)\n", [AKPUtilities stringForPolicy:type].UTF8String);
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
	}else if (mode == AKPPolicyModeNonPersist){
		dispatch_semaphore_t sema = dispatch_semaphore_create(0);
		
		if (setPolicyForced && !daemonMode && !globalMode){
			if (type != AKPPolicyTypeUnknown){
				[AKPNEUtilities setPolicyForAll:type reply:^(NSArray <NSNumber *>*successes, NSDictionary *policies, NSError *error){
					if (error){
						fprintf(stderr, "ERROR: Unable to set policy: %s\n", error.localizedDescription.UTF8String);
					}else{
						fprintf(stdout, "Policy set to \"%s\" (ALL, NON-PERSISTENT)\n", [AKPUtilities stringForPolicy:type].UTF8String);
					}
					[AKPUtilities setValue:policies forKey:@"daemonTamingValue"];
					dispatch_semaphore_signal(sema);
				}];
			}else{
				dispatch_semaphore_signal(sema);
			}
		}else{
			
			[AKPNEUtilities currentPoliciesWithReply:^(NSDictionary *policies){
				NSMutableDictionary *policy = [policies[@(argv[0])] ?: @{} mutableCopy];
				if (setPolicy){
					if (type != AKPPolicyTypeUnknown){
						NSDictionary *newParams = @{
							kPolicingOrder : @(AKPPolicingOrderDaemon),
							(daemonMode ? kPath : kBundleID) : @(argv[0]),
							kPolicy : @(type)
						};
						[policy addEntriesFromDictionary:newParams];
					}
					if (secundasRule != AKPDaemonTrafficRuleUnknown){
						NSDictionary *newParams = @{
							kPolicingOrder : @(AKPPolicingOrderDaemon),
							(daemonMode ? kPath : kBundleID) : @(argv[0]),
							kSecundasRule : @(secundasRule)
						};
						[policy addEntriesFromDictionary:newParams];
					}
					if (tertiusRule != AKPDaemonTrafficRuleUnknown){
						NSDictionary *newParams = @{
							kPolicingOrder : @(AKPPolicingOrderDaemon),
							(daemonMode ? kPath : kBundleID) : @(argv[0]),
							kTertiusRule : @(tertiusRule)
						};
						[policy addEntriesFromDictionary:newParams];
					}
					NSDictionary *cleansedPolicy = [AKPUtilities cleansedPolicyDict:policy];
					[AKPUtilities setDaemonTamingValue:cleansedPolicy forKey:@(argv[0])];
					[AKPNEUtilities setPolicyWithInfo:cleansedPolicy reply:^(NSError *error){
						if (error){
							fprintf(stderr, "ERROR: Unable to set policy for %s!\n", argv[0]);
						}else{
							fprintf(stdout, "Policy set to \"%s\" (NON-PERSISTENT)\n", [AKPUtilities stringForPolicy:type].UTF8String);
						}
						dispatch_semaphore_signal(sema);
					}];
				}else{
					AKPPolicyType currentPolicy = [policy[kPolicy] ?: @(AKPPolicyTypeAllAllow) intValue];
					fprintf(stdout, "%s\n",  [AKPUtilities stringForPolicy:currentPolicy].UTF8String);
					dispatch_semaphore_signal(sema);
				}
			}];
		}
		SEMA_TIMEOUT(sema, TIMEOUT);
		CFRELASE_AND_RETURN(0);
	}
	
	CFRELASE_AND_RETURN(0);
}
