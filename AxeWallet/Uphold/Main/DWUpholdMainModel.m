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
#import <AxeSync/UIImage+DSUtils.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWUpholdMainModel ()

@property (assign, nonatomic) DWUpholdMainModelState state;
@property (nullable, strong, nonatomic) DWUpholdCardObject *axeCard;
@property (nullable, copy, nonatomic) NSArray<DWUpholdCardObject *> *fiatCards;

@end

@implementation DWUpholdMainModel

- (void)fetch {
    self.state = DWUpholdMainModelStateLoading;

    __weak typeof(self) weakSelf = self;

    [[DWUpholdClient sharedInstance] getCards:^(DWUpholdCardObject *_Nullable axeCard, NSArray<DWUpholdCardObject *> *_Nonnull fiatCards) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        strongSelf.axeCard = axeCard;
        strongSelf.fiatCards = fiatCards;
        BOOL success = !!strongSelf.axeCard;
        strongSelf.state = success ? DWUpholdMainModelStateDone : DWUpholdMainModelStateFailed;
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

    NSTextAttachment *axeAttachmentSymbol = [[NSTextAttachment alloc] init];
    axeAttachmentSymbol.bounds = CGRectMake(0.0, -1.0, 14.0, 11.0);
    axeAttachmentSymbol.image = [[UIImage imageNamed:@"Axe-Light"] ds_imageWithTintColor:UIColorFromRGB(0x008DE4)];
    NSAttributedString *axeSymbol = [NSAttributedString attributedStringWithAttachment:axeAttachmentSymbol];
    NSString *available = [self.axeCard.available descriptionWithLocale:[NSLocale currentLocale]];
    NSString *availableFormatted = [NSString stringWithFormat:@" %@", available];
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    [result beginEditing];
    [result appendAttributedString:axeSymbol];
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:availableFormatted]];
    [result endEditing];
    return [result copy];
}

- (void)logOut {
    [[DWUpholdClient sharedInstance] logOut];
}

@end

NS_ASSUME_NONNULL_END
