//
//  TouchIDLogin.h
//  Copyright (c) 2016 Jeff Wang
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface TouchIDLogin : NSObject
- (BOOL) checkSupport;
- (BOOL) checkKey;
- (BOOL) save:(NSDictionary*)credential;
- (BOOL) onlySaveUser:(NSString*)username;
- (void) verify:(NSString*)message replyPass:(void(^)(BOOL, NSDictionary*))callback;
- (BOOL) remove:(NSString*)userKey;
- (void) onlyVerifyUser:(void(^)(BOOL, NSDictionary*))callback;
@end