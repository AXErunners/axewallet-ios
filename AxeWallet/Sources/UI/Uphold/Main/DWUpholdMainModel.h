//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Axe Core Group. All rights reserved.
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

#import "DWUpholdCardObject.h"

NS_ASSUME_NONNULL_BEGIN

@class DWUpholdTransactionObject;

typedef NS_ENUM(NSUInteger, DWUpholdMainModelState) {
    DWUpholdMainModelState_Loading,
    DWUpholdMainModelState_Done,
    DWUpholdMainModelState_Failed,
};

@interface DWUpholdMainModel : NSObject

@property (readonly, assign, nonatomic) DWUpholdMainModelState state;
@property (readonly, nullable, strong, nonatomic) DWUpholdCardObject *axeCard;
@property (readonly, nullable, copy, nonatomic) NSArray<DWUpholdCardObject *> *fiatCards;

- (void)fetch;

- (nullable NSURL *)buyAxeURL;
- (nullable NSAttributedString *)availableAxeString;
- (void)logOut;

- (nullable NSURL *)transactionURLForTransaction:(DWUpholdTransactionObject *)transaction;
- (NSString *)successMessageTextForTransaction:(DWUpholdTransactionObject *)transaction;

@end

NS_ASSUME_NONNULL_END
