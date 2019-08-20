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

#import "DWUpholdAmountObject.h"

#import "DWAmountObject.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DWUpholdAmountObject

@synthesize axeAttributedString=_axeAttributedString;
@synthesize localCurrencyAttributedString=_localCurrencyAttributedString;

- (instancetype)initWithAxeInternalRepresentation:(NSString *)axeInternalRepresentation
                       localInternalRepresentation:(NSString *)localInternalRepresentation
                            localCurrencyFormatted:(NSString *)localCurrencyFormatted {
    self = [super init];
    if (self) {
        if (axeInternalRepresentation.length == 0) {
            axeInternalRepresentation = @"0";
        }
        if (localInternalRepresentation.length == 0) {
            localInternalRepresentation = @"0";
        }
        
        _axeInternalRepresentation = axeInternalRepresentation;
        _localInternalRepresentation = localInternalRepresentation;
        
        // TODO: format axe value
        
        _localCurrencyAttributedString = [DWAmountObject attributedStringForLocalCurrencyFormatted:localCurrencyFormatted
                                                                                         textColor:[UIColor blackColor]];
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
