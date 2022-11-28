//
//  OrientationPlugin.m
//  orientation
//
//  Created by 王潇 on 2022/11/28.
//

#import "OrientationPlugin.h"
#import <orientation/orientation-Swift.h>

@implementation OrientationPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftOrientationPlugin registerWithRegistrar:registrar];
}
@end
