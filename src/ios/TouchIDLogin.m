#import "TouchIDLogin.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "KeychainWrapper.h"
#import <LocalAuthentication/LocalAuthentication.h>

@interface TouchIDLogin ()
@property (strong, nonatomic) LAContext* laContext;
@property (strong, nonatomic) KeychainWrapper* keychainWrapper;
@end

@implementation TouchIDLogin

- (instancetype) init
{
    self = [super init];
    if (self) {
        _laContext = [[LAContext alloc] init];
        _keychainWrapper = [[KeychainWrapper alloc] init];
    };
    return self;
}

- (BOOL) checkSupport
{
    if (NSClassFromString(@"LAContext") != nil)
    {
        NSError *authError = nil;
        if ([_laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                                   error:&authError]) {
            if (authError)
                [NSException raise:authError.domain format:@"Exception: %@", authError.localizedDescription];
            else
                return YES;
        }
    }
    
    return NO;
}

- (BOOL) checkKey
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"CoviuKey"];
}

- (BOOL) save:(NSDictionary*)credential
{
    @try {
        [_keychainWrapper mySetObject:credential[@"password"] forKey:(__bridge id)(kSecValueData)];
        [_keychainWrapper writeToKeychain];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"CoviuKey"];
        [[NSUserDefaults standardUserDefaults] setValue:credential[@"username"] forKey:@"username"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return YES;
    }
    @catch(NSException *exception){
        return NO;
    }
}

-(BOOL) remove:(NSString*)userKey
{
    @try {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:userKey];
        return YES;
    }
    @catch(NSException *exception) {
        return NO;
    }
}

-(void) verify:(NSString*)message replyPass:(void(^)(BOOL, NSDictionary*))callback
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"CoviuKey"]) {
        NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
        if([self checkSupport]) {
            [_laContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                       localizedReason:message
                                 reply:^(BOOL success, NSError *error) {
                                     if(success){
                                         callback(success, @{@"username":username,
                                                             @"password":[_keychainWrapper myObjectForKey:@"v_Data"]
                                                             });
                                     }
                                     if (error) {
                                         callback(NO, @{@"error":error.localizedDescription,
                                                        @"username":username});
                                     }
                                 }];
        } else {
            callback(NO, @{@"error":@"Touch ID not availalbe",
                           @"username":username});
        }
    } else {
        callback(NO, @{@"error":@"No credential in chain"});
    }
}
@end