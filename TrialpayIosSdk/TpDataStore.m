//
// Created by Daniel Togni on 9/27/13.
// Copyright (c) 2013 TrialPay Inc. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "BaseTrialpayManager.h"
#import "TpDataStore.h"


@implementation TpDataStore {
    NSMutableDictionary *_trialpayManagerDictionary;
}

// trigger error if already initialized
static BOOL __initialized = NO;

// singleton
static TpDataStore *__trialpayDataStoreSingleton;
+ (TpDataStore *)sharedInstance {
    if (__trialpayDataStoreSingleton) return __trialpayDataStoreSingleton;
    __trialpayDataStoreSingleton = [[TpDataStore alloc] init];
    __initialized = YES;
    return __trialpayDataStoreSingleton;
}

#pragma mark - Handling dictionary in TrialpayManager.plist

- (NSString *)path {
// Get path
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:@"TrialpayManager.plist"];
    return path;
}

- (NSMutableDictionary *)dataDictionary {
    TPLogEnter;
    if (nil == _trialpayManagerDictionary) {
        NSString *path= [self path];

        // If the file exists - get the content from there. If not, create an empty dictionary
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            _trialpayManagerDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
        } else {
            _trialpayManagerDictionary = [[NSMutableDictionary alloc] init];
        }
    }
    return _trialpayManagerDictionary;
}

- (BOOL)saveDataDictionary {
    TPLogEnter;
    if (nil != _trialpayManagerDictionary) {
        NSString *path= [self path];
        return [_trialpayManagerDictionary writeToFile:path atomically:YES];
    }
    return NO;
}

- (void) clearDataDictionary {
    NSError *error;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString *path= [self path];
    if ([fileMgr fileExistsAtPath:path]) {
        if ([fileMgr removeItemAtPath:path error:&error] != YES) {
            TPLog(@"Unable to delete file: %@", [error localizedDescription]);
        } else {
            if (__initialized) {
                _trialpayManagerDictionary = [[NSMutableDictionary alloc] init];
                TPLog(@"PLEASE RESET THE APP: %@", [error localizedDescription]);
                [NSException raise:@"TrialpayManagerInconsistency" format:@"If dictionary is cleared and an instance of the manager was already created the behavior may be unpredictable"];
            }
        }
    } else {
        TPLog(@"File does not exist");
    }
}

- (BOOL)setDataWithValue:(NSObject *)value forKey:(NSString *)key {
    TPLog(@"setDataWithValue:%@ forKey:%@)", value, key);
    NSMutableDictionary* dict = [self dataDictionary];
    @synchronized (self) {
        [dict setValue:value forKey:key];
        BOOL res = [self saveDataDictionary];
        return res;
    }
}

- (id)dataValueForKey:(NSString *)key {
    TPLog(@"dataValueForKey:%@", key);
    NSDictionary *trialpayManagerDictionary = [self dataDictionary];
    return [trialpayManagerDictionary valueForKey:key];
}
@end