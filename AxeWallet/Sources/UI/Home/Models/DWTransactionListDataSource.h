//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Axe Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <UIKit/UIKit.h>

#import "DWDPRegistrationErrorRetryDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@class DSTransaction;
@class DWDPRegistrationStatus;

@interface DWTransactionListDataSource : NSObject <UITableViewDataSource>

@property (nullable, nonatomic, weak) id<DWDPRegistrationErrorRetryDelegate> retryDelegate;

@property (nullable, readonly, nonatomic, strong) DWDPRegistrationStatus *registrationStatus;
@property (readonly, copy, nonatomic) NSArray<DSTransaction *> *items;
@property (readonly, nonatomic, assign, getter=isEmpty) BOOL empty;
@property (readonly, nonatomic, assign) BOOL showsRegistrationStatus;

- (nullable DSTransaction *)transactionForIndexPath:(NSIndexPath *)indexPath;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
