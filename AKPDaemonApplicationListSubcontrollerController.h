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
#import <AltList/ATLApplicationListSubcontrollerController.h>

@interface AKPDaemonApplicationListSubcontrollerController : ATLApplicationListSubcontrollerController{
}
@property (nonatomic, strong) NSDictionary *policies;
-(PSSpecifier *)specifierByInfo:(NSDictionary *)info;
-(void)reloadSpecifierByInfo:(NSDictionary *)info animated:(BOOL)animated;
@end
