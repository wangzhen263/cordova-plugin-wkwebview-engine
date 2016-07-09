//
//  WKWebViewTouchDelegate.m
//  COVIU
//
//  Created by Jeff Wang on 9/07/2016.
//
//
@import UIKit;
#import "WKWebViewTouchDelegate.h"
#import "TouchIDLogin.h"

#define ERROR_SIGN_IN_PARAM @"loginError"

@interface WKWebViewTouchDelegate ()
@property (assign, nonatomic) id<WKNavigationDelegate> delegate;
@property (strong, nonatomic) NSString* path;
@property (strong, nonatomic) TouchIDLogin* touchID;
@property (strong, nonatomic) NSMutableArray* backList;
@end

@implementation WKWebViewTouchDelegate

- (instancetype)initWithDelegate:(id<WKNavigationDelegate>)delegate
                        loginTag:(NSString*)path
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _path = path;
        _touchID = [[TouchIDLogin alloc] init];
        _backList = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark WKWebView Delegate Functions
- (void)webView:(WKWebView*)webView didStartProvisionalNavigation:(WKNavigation*)navigation
{
    NSLog(@"didStartProvisionalNavigation %@ %@", webView.URL, webView.URL.query);
    if (_backList.count > 0) {
        if ([((NSURL*)[_backList lastObject]).path containsString:_path]
            && [_touchID checkSupport])
        {
            if (![_touchID checkKey] || [((NSURL*)[_backList lastObject]).query containsString:ERROR_SIGN_IN_PARAM])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *jsCall = @"var elemEmails = document.getElementsByName('email');\
                    var elemPwd = document.getElementsByName('password');\
                    if (elemEmails.length == 1 && elemEmails[0].type == 'email' && elemPwd.length == 1 && elemPwd[0].type == 'password'){\
                    [elemEmails[0].value,elemPwd[0].value]\
                    }";
                    [webView evaluateJavaScript:jsCall completionHandler:^(id result, NSError *error) {
                        if (error == nil) {
                            NSArray* retArray = (NSArray*)result;
                            if (result != nil && [_touchID save:@{@"username":retArray[0],
                                                                  @"password":retArray[1]}]) {
                                UIAlertController * alert = [UIAlertController
                                                             alertControllerWithTitle:@"Thanks"
                                                             message:@"You can login Coviu via fingerprint next time."
                                                             preferredStyle:UIAlertControllerStyleAlert];
                                UIAlertAction* okButton = [UIAlertAction
                                                           actionWithTitle:@"Okay"
                                                           style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                           }];
                                [alert addAction:okButton];
                                
                                id object = [webView nextResponder];
                                while (![object isKindOfClass:[UIViewController class]] &&
                                       object != nil) {
                                    object = [object nextResponder];
                                }
                                
                                [(UIViewController*)object presentViewController:alert animated:YES completion:nil];
                            }
                        } else {
                            NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
                        }
                    }];
                });
            }
        }
    }
    
    [_delegate webView:webView didStartProvisionalNavigation:navigation];
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation
{
    [_backList addObject:webView.URL];
    if ([webView.URL.path containsString:_path]
        && [_touchID checkSupport]
        && [_touchID checkKey]
        && ![((NSURL*)[_backList lastObject]).query containsString:ERROR_SIGN_IN_PARAM])
    {
        [_touchID verify:@"Enter Coviu via fingerprint" replyPass:^(BOOL success, NSDictionary* ret){
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *autoLogin = [NSString stringWithFormat:@"var elemEmails = document.getElementsByName('email');\
                    var elemPwd = document.getElementsByName('password');\
                    if (elemEmails.length == 1 && elemEmails[0].type == 'email' && elemPwd.length == 1 && elemPwd[0].type == 'password'){\
                    elemEmails[0].value = '%@';\
                    elemPwd[0].value = '%@';\
                    elemEmails[0].parentNode.submit();\
                    }", ret[@"username"], ret[@"password"]];
                    [webView evaluateJavaScript:autoLogin completionHandler:^(id result, NSError *error) {
                        if (error) {
                            NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
                        }
                    }];
                });
            } else {
                NSLog(@"Error: %@", ret);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (ret[@"username"]) {
                        NSString *addEmail = [NSString stringWithFormat:@"var elemEmails =\
                                            document.getElementsByName('email');\
                                            if (elemEmails.length == 1 && elemEmails[0].type == 'email'){\
                                            elemEmails[0].value = '%@';\
                                            }", ret[@"username"]];
                        [webView evaluateJavaScript:addEmail completionHandler:^(id result, NSError *error) {
                            if (error) {
                                NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
                            }
                        }];
                    }
                    
                    if ([ret[@"error"] containsString:@"Canceled by user"]
                        || [ret[@"error"] containsString:@"Fallback authentication"]) {
                        return;
                    }
                    
                    UIAlertController * alert = [UIAlertController
                                                 alertControllerWithTitle:@"Error on fingerprint"
                                                 message:ret[@"error"]
                                                 preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction* okButton = [UIAlertAction
                                               actionWithTitle:@"Okay"
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                               }];
                    [alert addAction:okButton];
                    
                    id object = [webView nextResponder];
                    while (![object isKindOfClass:[UIViewController class]] &&
                           object != nil) {
                        object = [object nextResponder];
                    }
                    
                    [(UIViewController*)object presentViewController:alert animated:YES completion:nil];
                });
            }
        }];
    }
    
    [_delegate webView:webView didFinishNavigation:navigation];
}

- (void)webView:(WKWebView*)theWebView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
    [_delegate webView:theWebView didFailNavigation:navigation withError:error];
}

- (void) webView: (WKWebView *) webView decidePolicyForNavigationAction: (WKNavigationAction*) navigationAction decisionHandler: (void (^)(WKNavigationActionPolicy)) decisionHandler
{
    [_delegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
}

@end