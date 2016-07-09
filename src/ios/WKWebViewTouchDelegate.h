//
//  WKWebViewTouchDelegate.h
//  COVIU
//
//  Created by Jeff Wang on 9/07/2016.
//
//

#import <WebKit/WebKit.h>

@interface WKWebViewTouchDelegate : NSObject <WKNavigationDelegate>
- (instancetype)initWithDelegate:(id<WKNavigationDelegate>)delegate
                        loginTag:(NSString*)path;
@end