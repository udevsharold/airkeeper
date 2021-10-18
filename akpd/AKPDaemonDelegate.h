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

#ifdef __cplusplus
extern "C" {
#endif

xpc_object_t xpc_connection_copy_entitlement_value(xpc_connection_t connection, const char *entitlement);

#ifdef __cplusplus
}
#endif

@interface AKPDaemonDelegate : NSObject <NSXPCListenerDelegate>
@end
