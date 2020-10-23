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

#import "DWMinLengthUsernameValidationRule.h"

#import "DWAxePayConstants.h"
#import "DWUsernameValidationRule+Protected.h"

@implementation DWMinLengthUsernameValidationRule

- (NSString *)title {
    return NSLocalizedString(@"Minimum 3 characters", @"Validation rule");
}

- (void)validateText:(NSString *_Nullable)text {
    const NSUInteger length = text.length;
    if (length == 0) {
        self.validationResult = DWUsernameValidationRuleResultEmpty;
        return;
    }

    self.validationResult = length >= DW_MIN_USERNAME_LENGTH ? DWUsernameValidationRuleResultValid : DWUsernameValidationRuleResultInvalid;
}

@end
