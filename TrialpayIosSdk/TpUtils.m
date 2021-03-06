//
//  TpUtils.m
//  baseSdk
//
//  Created by Yoav Yaari on 5/30/13.
//  Copyright (c) 2013 Yoav Yaari. All rights reserved.
//

#import "TpUtils.h"
#import "TpArcSupport.h"
#import <UIKit/UIKit.h>
#import <libkern/OSAtomic.h>


#if !defined(TRIALPAY_VERBOSE)
BOOL __trialpayVerbose=NO;
#else
BOOL __trialpayVerbose=YES;
#endif

@implementation TpUtils

+ (void)verboseLogging:(BOOL)verbose {
    __trialpayVerbose = verbose;
}

+ (NSString*)appVersion {
    NSString* version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    return [NSString stringWithFormat:@"%@", version];
}

+ (BOOL)idfa_enabled {
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
    if (NSClassFromString(@"ASIdentifierManager")) {
        return [ASIdentifierManager sharedManager].advertisingTrackingEnabled;
    }
#endif
    return NO;
}

+ (NSString*)idfa {
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
    if (NSClassFromString(@"ASIdentifierManager")) {
        return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    }
#endif
    return @"";
}

+ (NSString *)macAddress {
    int                 mgmtInfoBase[6];
    char                *msgBuffer = NULL;
    size_t              length;
    unsigned char       macAddress[6];
    struct if_msghdr    *interfaceMsgStruct;
    struct sockaddr_dl  *socketStruct;
    NSString            *errorFlag = NULL;
    
    // Setup the management Information Base (mib)
    mgmtInfoBase[0] = CTL_NET;        // Request network subsystem
    mgmtInfoBase[1] = AF_ROUTE;       // Routing table info
    mgmtInfoBase[2] = 0;
    mgmtInfoBase[3] = AF_LINK;        // Request link layer information
    mgmtInfoBase[4] = NET_RT_IFLIST;  // Request all configured interfaces
    
    // With all configured interfaces requested, get handle index
    if ((mgmtInfoBase[5] = if_nametoindex("en0")) == 0) {
        errorFlag = @"if_nametoindex failure";
    } else {
        // Get the size of the data available (store in len)
        if (sysctl(mgmtInfoBase, 6, NULL, &length, NULL, 0) < 0) {
            errorFlag = @"sysctl mgmtInfoBase failure";
        } else {
            // Alloc memory based on above call
            if ((msgBuffer = malloc(length)) == NULL) {
                errorFlag = @"buffer allocation failure";
            } else {
                // Get system information, store in buffer
                if (sysctl(mgmtInfoBase, 6, msgBuffer, &length, NULL, 0) < 0) {
                    errorFlag = @"sysctl msgBuffer failure";
                }
            }
        }
    }
    
    // Before going any further...
    if (errorFlag != NULL) {
        TPLog(@"Error: %@", errorFlag);
        if (msgBuffer != NULL) {
            free(msgBuffer);
        }
        return @"";
    }
    
    // Map msgbuffer to interface message structure
    interfaceMsgStruct = (struct if_msghdr *) msgBuffer;
    
    // Map to link-level socket structure
    socketStruct = (struct sockaddr_dl *) (interfaceMsgStruct + 1);
    
    // Copy link layer address data in socket structure to an array
    memcpy((void*)&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);
    
    // Read from char array into a string object, into traditional Mac address format
    NSString *macAddressString = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X",
                                  macAddress[0], macAddress[1], macAddress[2],
                                  macAddress[3], macAddress[4], macAddress[5]];
    
    // Release the buffer memory
    free(msgBuffer);
    
    if (macAddress[0] == 2 && macAddress[1] == macAddress[2] == macAddress[3] == macAddress[4] == macAddress[5] == 0) {
        // iOS7 result in 02000000000000, so lets return an empty string
        return @"";
    }
    
    return macAddressString;
}

+ (NSString *)sha1:(NSString *)input {
    const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:input.length];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

/*
 * Returns the code for given gender ("M" for Male, "F" for Female and "U" for Unknown).
 */
+ (NSString *)genderCodeForValue:(Gender)gender {
    TPLog(@"getGenderCodeForValue:%u", gender);
    switch (gender) {
        case Male: return @"M";
        case Female: return @"F";
        default: return @"U"; // unknown gender
    }
}

/*
 * Returns the code for given gender ("M" for Male, "F" for Female and "U" for Unknown).
 */
+ (Gender)genderValueForCode:(NSString*)genderStr {
    TPLog(@"getGenderValueForCode:%@", genderStr);
    if ([genderStr isEqualToString:@"M"]) return Male;
    if ([genderStr isEqualToString:@"F"]) return Female;
    return Unknown;
}

/*
 * Returns the mode name from enum (debug purposes)
 */
+ (NSString *)viewModeString:(TPViewMode)mode {
    switch (mode) {
        case TPViewModeUnknown:
        case TPViewModeFullscreen: return @"Fullscreen";
        case TPViewModePopup: return @"Popup";
    }
    return @"UNKNOWN";
}

/*
 * Determine whether the app supports portrait and/or landscape orientations.
 * Returns a 2-bit mask, where minor bit indicates portrait support and major bit is landscape support:
 *   0 - neither orientation supported (this should never occur)
 *   1 - portrait is supported, landscape is not
 *   2 - landscape is supported, portrait is not
 *   3 - both orientations are supported
 */
+ (int)getBasicOrientationSupport {
    NSUInteger supportedOrientationMask;
    int basicMask = 0;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app.delegate respondsToSelector:@selector(application:supportedInterfaceOrientationsForWindow:)]) {
        supportedOrientationMask = [app.delegate application:app supportedInterfaceOrientationsForWindow:app.keyWindow];
    } else if ([app respondsToSelector:@selector(supportedInterfaceOrientationsForWindow:)]) {
        supportedOrientationMask = [app supportedInterfaceOrientationsForWindow:app.keyWindow];
    } else {
        // iOS 5 does not support supportedInterfaceOrientationsForWindow:, lets consider the current orientation as the mask ...
        supportedOrientationMask = (NSUInteger) (1 << [app statusBarOrientation]); // we are relying on the way apple calculated the masks
    }
    if (supportedOrientationMask & (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown)) {
        basicMask += 1; // app supports portrait
    }
    if (supportedOrientationMask & (UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight)) {
        basicMask += 2; // app supports landscape
    }
    return basicMask;
}

+ (void)operation:(NSOperation*)operation sleepFor:(int)secondsValid {
    // Lets allow the thread to die quickly (20s) if it was canceled during the wait
    // and wait period is long: one day/week
    int totalWait = 0;
    int stepWait = 20; // wait 20 sec at a time.
    while (totalWait < secondsValid && ![operation isCancelled]) {
        [NSThread sleepForTimeInterval:stepWait];
        totalWait += stepWait;
    }
}

static volatile BOOL _singleFlowLock = NO;
static volatile int _singleFlowCount = 0;
+ (BOOL)singleFlowLockWithMessage:(NSString*)name {
    if (false == OSAtomicTestAndSet(0, &_singleFlowLock)) {
        _singleFlowCount ++;
        int pc = _singleFlowCount;
        TPLog(@"[singleFlowLock] %@", name);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            // lets force release flow after 7s if never protected by someone else, we seen apptrailer taking 5s to launch on ipod5 ios8
            if (_singleFlowLock) {
                if (_singleFlowCount == pc) {
                    _singleFlowLock = NO;
                }
            }
        });
        return YES; // proceed on flow
    } else {
        TPLog(@"[singleFlowLock] SKIP %@", name);
    }
    return NO; // stop flow
}

+ (void)singleFlowUnlockWithMessage:(NSString*)name {
    TPLog(@"[singleFlowUnlock] %@", name);
    _singleFlowLock = NO;
}



@end

#pragma mark - TpUserAgent

@implementation TpUserAgent

TpUserAgent *__TpUserAgentSingleton = nil;
+ (TpUserAgent *)sharedInstance {
    if (__TpUserAgentSingleton) return __TpUserAgentSingleton;
    __TpUserAgentSingleton = [[TpUserAgent alloc] init];
    return __TpUserAgentSingleton;
}

-(void)populateUserAgent {
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    self.userAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    [webView TP_RELEASE];
}

- (void)dealloc {
    [super TP_DEALLOC];
}

@end
