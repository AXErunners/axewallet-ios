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

#import "DWUpholdMainModel.h"

#import "DWUpholdClient.h"
#import "DWUpholdTransactionObject.h"
#import "NSAttributedString+DWBuilder.h"
#import "UIColor+DWStyle.h"
#import "UIFont+DWFont.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWUpholdMainModel ()

@property (assign, nonatomic) DWUpholdMainModelState state;
@property (nullable, strong, nonatomic) DWUpholdCardObject *axeCard;
@property (nullable, copy, nonatomic) NSArray<DWUpholdCardObject *> *fiatCards;

@end

@implementation DWUpholdMainModel

- (void)fetch {
    self.state = DWUpholdMainModelState_Loading;

    __weak typeof(self) weakSelf = self;

    [[DWUpholdClient sharedInstance] getCards:^(DWUpholdCardObject *_Nullable axeCard, NSArray<DWUpholdCardObject *> *_Nonnull fiatCards) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        strongSelf.axeCard = axeCard;
        strongSelf.fiatCards = fiatCards;
        BOOL success = !!strongSelf.axeCard;
        strongSelf.state = success ? DWUpholdMainModelState_Done : DWUpholdMainModelState_Failed;
    }];
}

- (nullable NSURL *)buyAxeURL {
    NSParameterAssert(self.axeCard);
    return [[DWUpholdClient sharedInstance] buyAxeURLForCard:self.axeCard];
}

- (nullable NSAttributedString *)availableAxeString {
    if (!self.axeCard.available) {
        return nil;
    }

    NSString *available = [self.axeCard.available descriptionWithLocale:[NSLocale currentLocale]];
    NSAttributedString *result = [NSAttributedString
        dw_axeAttributedStringForFormattedAmount:available
                                        tintColor:[UIColor dw_axeBlueColor]
                                             font:[UIFont dw_fontForTextStyle:UIFontTextStyleTitle3]];
    return result;
}

- (void)logOut {
    [[DWUpholdClient sharedInstance] logOut];
}

- (nullable NSURL *)transactionURLForTransaction:(DWUpholdTransactionObject *)transaction {
    return [[DWUpholdClient sharedInstance] transactionURLForTransaction:transaction];
}

- (NSString *)successMessageTextForTransaction:(DWUpholdTransactionObject *)transaction {
    return [NSString stringWithFormat:@"%@\n%@: %@",
                                      NSLocalizedString(@"Your transaction was sent and the amount should appear in your wallet in a few minutes.", nil),
                                      NSLocalizedString(@"Transaction id", nil),
                                      transaction.identifier];
}


@end

NS_ASSUME_NONNULL_END
