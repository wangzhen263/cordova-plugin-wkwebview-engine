#import "TouchIDLogin.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "KeychainWrapper.h"
#import <LocalAuthentication/LocalAuthentication.h>

#define COVIU_KEY_NAME  @"CoviuKey"
#define COVIU_USER_NAME @"CoviuUser"

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
    return [[NSUserDefaults standardUserDefaults] boolForKey:COVIU_KEY_NAME];
}

- (BOOL) save:(NSDictionary*)credential
{
    @try {
        [_keychainWrapper mySetObject:credential[@"password"] forKey:(__bridge id)(kSecValueData)];
        [_keychainWrapper writeToKeychain];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:COVIU_KEY_NAME];
        [[NSUserDefaults standardUserDefaults] setValue:credential[@"username"] forKey:COVIU_USER_NAME];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return YES;
    }
    @catch(NSException *exception){
        return NO;
    }
}

- (BOOL) onlySaveUser:(NSString*)username
{
    @try {
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:COVIU_KEY_NAME];
        [[NSUserDefaults standardUserDefaults] setValue:username forKey:COVIU_USER_NAME];
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
    if([[NSUserDefaults standardUserDefaults] boolForKey:COVIU_KEY_NAME]) {
        NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:COVIU_USER_NAME];
        if([self checkSupport] && username) {
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
            if (!username) {
                username = @"";
                [self remove:COVIU_KEY_NAME];
            }
            callback(NO, @{@"error":@"Touch ID not availalbe",
                           @"username":username});
        }
    } else {
        callback(NO, @{@"error":@"No credential in chain"});
    }
}

-(void) onlyVerifyUser:(void(^)(BOOL, NSDictionary*))callback
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:COVIU_KEY_NAME]) {
        NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:COVIU_USER_NAME];
        if (!username) {
            username = @"";
            [self remove:COVIU_KEY_NAME];
        }
        callback(YES, @{@"username":username});
    } else {
        callback(NO, @{@"error":@"No user in chain"});
    }
}
@end