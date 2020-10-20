//
//  DWDataMigrationManager.m
//  axewallet
//
//  Created by Andrew Podkovyrin on 08/11/2018.
//  Copyright © 2019 Axe Core. All rights reserved.
//

#import "DWDataMigrationManager.h"

#import "DWEnvironment.h"

#import <AxeSync/DSAccountEntity+CoreDataClass.h>
#import <AxeSync/DSChain.h>
#import <AxeSync/DSChainEntity+CoreDataClass.h>
#import <AxeSync/AxeSync.h>

NS_ASSUME_NONNULL_BEGIN

@implementation DWDataMigrationManager

+ (instancetype)sharedInstance {
    static DWDataMigrationManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _shouldMigrateDatabase = [DSCoreDataMigrator requiresMigration];
        _shouldMigrateWalletKeys = ![[DSVersionManager sharedInstance] noOldWallet];
        _shouldMigrate = _shouldMigrateDatabase || _shouldMigrateWalletKeys;
    }
    return self;
}

- (BOOL)isMigrationSuccessful {
    return YES;
}

- (void)migrate:(void (^)(BOOL completed))completion {
    NSAssert([NSThread isMainThread], @"Main thread is assumed here");

    if (![DSCoreDataMigrator requiresMigration]) {
        completion(YES);
        return;
    }

    [DSCoreDataMigrator performMigrationWithCompletionQueue:dispatch_get_main_queue()
                                                 completion:^{
                                                     completion(YES);
                                                 }];
}

@end

NS_ASSUME_NONNULL_END
