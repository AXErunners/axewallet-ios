//
//  Created by Andrew Podkovyrin
//  Copyright © 2020 Axe Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const DWAxePayRegistrationStatusUpdatedNotification;

@class DWDPRegistrationStatus;

@protocol DWAxePayProtocol <NSObject>

@property (nullable, readonly, nonatomic, copy) NSString *username;
@property (nullable, readonly, nonatomic, strong) DWDPRegistrationStatus *registrationStatus;
@property (nullable, readonly, nonatomic, strong) NSError *lastRegistrationError;
@property (readonly, nonatomic, assign) BOOL registrationCompleted;
@property (readonly, nonatomic, assign) NSUInteger unreadNotificationsCount;

- (BOOL)shouldPresentRegistrationPaymentConfirmation;
- (void)createUsername:(NSString *)username;
- (BOOL)canRetry;
- (void)retry;
- (void)completeRegistration;
- (void)updateUsernameStatus;

@end

NS_ASSUME_NONNULL_END
