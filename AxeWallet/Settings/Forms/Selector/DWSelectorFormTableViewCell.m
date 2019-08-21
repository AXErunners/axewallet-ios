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

#import "DWSelectorFormTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface DWSelectorFormTableViewCell ()

@end

@implementation DWSelectorFormTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    [self mvvm_observe:@"cellModel.title" with:^(__typeof(self) self, NSString * value) {
        self.textLabel.text = value;
    }];

    [self mvvm_observe:@"cellModel.subTitle" with:^(__typeof(self) self, NSString * value) {
        self.detailTextLabel.text = value;
    }];

    [self mvvm_observe:@"cellModel.accessoryType" with:^(__typeof(self) self, NSNumber * value) {
        self.accessoryType = value.integerValue;
    }];

    [self mvvm_observe:@"cellModel.style" with:^(__typeof(self) self, NSNumber * value) {
        DWSelectorFormCellModelStyle style = value.unsignedIntegerValue;
        UIColor *color = nil;
        switch (style) {
            case DWSelectorFormCellModelStyleBlack:
                color = [UIColor blackColor];
                break;
            case DWSelectorFormCellModelStyleBlue:
                color = UIColorFromRGB(0x007AFF);
                break;
            case DWSelectorFormCellModelStyleRed:
                color = [UIColor redColor];
                break;
        }
        self.textLabel.textColor = color;
    }];
}

@end

NS_ASSUME_NONNULL_END