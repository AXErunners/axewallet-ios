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

#import "DWAmountObject.h"

#import <AxeSync/AxeSync.h>

#import "DWAmountInputValidator.h"
#import "UIColor+DWStyle.h"

NS_ASSUME_NONNULL_BEGIN

static CGSize const AxeSymbolBigSize = {35.0, 27.0};
static CGSize const AxeSymbolSmallSize = {14.0, 11.0};

typedef NS_ENUM(NSUInteger, DWAmountObjectInternalType) {
    DWAmountObjectInternalType_Axe,
    DWAmountObjectInternalType_Local,
};

@interface DWAmountObject ()

@property (readonly, assign, nonatomic) DWAmountObjectInternalType internalType;

@end

@implementation DWAmountObject

@synthesize axeAttributedString = _axeAttributedString;
@synthesize localCurrencyAttributedString = _localCurrencyAttributedString;

- (instancetype)initWithAxeAmountString:(NSString *)axeAmountString {
    self = [super init];
    if (self) {
        _internalType = DWAmountObjectInternalType_Axe;

        _amountInternalRepresentation = [axeAmountString copy];

        if (axeAmountString.length == 0) {
            axeAmountString = @"0";
        }

        NSDecimalNumber *axeNumber = [NSDecimalNumber decimalNumberWithString:axeAmountString locale:[NSLocale currentLocale]];
        NSParameterAssert(axeNumber);
        NSDecimalNumber *haksNumber = (NSDecimalNumber *)[NSDecimalNumber numberWithLongLong:HAKS];
        int64_t plainAmount = [axeNumber decimalNumberByMultiplyingBy:haksNumber].longLongValue;
        _plainAmount = plainAmount;

        DSPriceManager *priceManager = [DSPriceManager sharedInstance];
        NSString *axeFormatted = [priceManager.axeFormat stringFromNumber:axeNumber];

        _axeFormatted = [self.class formattedAmountWithInputString:axeAmountString
                                                    formattedString:axeFormatted
                                                    numberFormatter:priceManager.axeFormat];
        _localCurrencyFormatted = [priceManager localCurrencyStringForAxeAmount:plainAmount];

        [self reloadAttributedData];
    }
    return self;
}

- (nullable instancetype)initWithLocalAmountString:(NSString *)localAmountString {
    self = [super init];
    if (self) {
        _internalType = DWAmountObjectInternalType_Local;

        _amountInternalRepresentation = [localAmountString copy];

        if (localAmountString.length == 0) {
            localAmountString = @"0";
        }

        NSDecimalNumber *localNumber = [NSDecimalNumber decimalNumberWithString:localAmountString locale:[NSLocale currentLocale]];
        NSParameterAssert(localNumber);

        DSPriceManager *priceManager = [DSPriceManager sharedInstance];
        NSAssert(priceManager.localCurrencyAxePrice, @"Prices should be loaded");
        NSString *localCurrencyFormatted = [priceManager.localFormat stringFromNumber:localNumber];
        uint64_t plainAmount = [priceManager amountForLocalCurrencyString:localCurrencyFormatted];
        if (plainAmount == 0 && ![localNumber isEqual:NSDecimalNumber.zero]) {
            return nil;
        }

        _plainAmount = plainAmount;
        _axeFormatted = [priceManager stringForAxeAmount:plainAmount];
        _localCurrencyFormatted = [self.class formattedAmountWithInputString:localAmountString
                                                             formattedString:localCurrencyFormatted
                                                             numberFormatter:priceManager.localFormat];

        [self reloadAttributedData];
    }
    return self;
}

- (instancetype)initAsLocalWithPreviousAmount:(DWAmountObject *)previousAmount
                       localCurrencyValidator:(DWAmountInputValidator *)localCurrencyValidator {
    self = [super init];
    if (self) {
        _internalType = DWAmountObjectInternalType_Local;

        DSPriceManager *priceManager = [DSPriceManager sharedInstance];
        _plainAmount = previousAmount.plainAmount;
        NSString *rawAmount = [self.class rawAmountStringFromFormattedString:previousAmount.localCurrencyFormatted
                                                             numberFormatter:priceManager.localFormat
                                                                   validator:localCurrencyValidator];
        NSParameterAssert(rawAmount);
        _amountInternalRepresentation = rawAmount;
        _axeFormatted = [previousAmount.axeFormatted copy];
        _localCurrencyFormatted = [previousAmount.localCurrencyFormatted copy];

        [self reloadAttributedData];
    }
    return self;
}

- (instancetype)initAsAxeWithPreviousAmount:(DWAmountObject *)previousAmount
                               axeValidator:(DWAmountInputValidator *)axeValidator {
    self = [super init];
    if (self) {
        _internalType = DWAmountObjectInternalType_Axe;

        DSPriceManager *priceManager = [DSPriceManager sharedInstance];
        _plainAmount = previousAmount.plainAmount;
        NSString *rawAmount = [self.class rawAmountStringFromFormattedString:previousAmount.axeFormatted
                                                             numberFormatter:priceManager.axeFormat
                                                                   validator:axeValidator];
        NSParameterAssert(rawAmount);
        _amountInternalRepresentation = rawAmount;
        _axeFormatted = [previousAmount.axeFormatted copy];
        _localCurrencyFormatted = [previousAmount.localCurrencyFormatted copy];

        [self reloadAttributedData];
    }
    return self;
}

- (instancetype)initWithPlainAmount:(uint64_t)plainAmount {
    NSDecimalNumber *plainNumber = (NSDecimalNumber *)[NSDecimalNumber numberWithUnsignedLongLong:plainAmount];
    NSDecimalNumber *haksNumber = (NSDecimalNumber *)[NSDecimalNumber numberWithLongLong:HAKS];
    NSDecimalNumber *axeNumber = [plainNumber decimalNumberByDividingBy:haksNumber];
    NSString *axeAmountString = [axeNumber descriptionWithLocale:[NSLocale currentLocale]];

    return [self initWithAxeAmountString:axeAmountString];
}

- (void)reloadAttributedData {
    NSParameterAssert(self.axeFormatted);
    NSParameterAssert(self.localCurrencyFormatted);

    const CGSize symbolSize = self.internalType == DWAmountObjectInternalType_Axe ? AxeSymbolBigSize : AxeSymbolSmallSize;
    UIColor *symbolTintColor = [UIColor dw_darkTitleColor];

    _axeAttributedString = [self.axeFormatted attributedStringForAxeSymbolWithTintColor:symbolTintColor
                                                                            axeSymbolSize:symbolSize];
    _localCurrencyAttributedString = [self.class attributedStringForLocalCurrencyFormatted:self.localCurrencyFormatted];
}

+ (NSAttributedString *)attributedStringForLocalCurrencyFormatted:(NSString *)localCurrencyFormatted textColor:(UIColor *)textColor {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:localCurrencyFormatted];
    NSLocale *locale = [NSLocale currentLocale];
    NSString *decimalSeparator = locale.decimalSeparator;
    NSString *insufficientFractionDigits = [NSString stringWithFormat:@"%@00", decimalSeparator];
    NSRange insufficientFractionDigitsRange = [localCurrencyFormatted rangeOfString:insufficientFractionDigits];
    NSDictionary *defaultAttributes = @{NSForegroundColorAttributeName : textColor};
    [attributedString beginEditing];
    if (insufficientFractionDigitsRange.location != NSNotFound) {
        if (insufficientFractionDigitsRange.location > 0) {
            NSRange beforeFractionRange = NSMakeRange(0, insufficientFractionDigitsRange.location);
            [attributedString setAttributes:defaultAttributes range:beforeFractionRange];
        }
        [attributedString setAttributes:@{NSForegroundColorAttributeName : [textColor colorWithAlphaComponent:0.5]}
                                  range:insufficientFractionDigitsRange];
        NSUInteger afterFractionIndex = insufficientFractionDigitsRange.location + insufficientFractionDigitsRange.length;
        if (afterFractionIndex < localCurrencyFormatted.length) {
            NSRange afterFractionRange = NSMakeRange(afterFractionIndex, localCurrencyFormatted.length - afterFractionIndex);
            [attributedString setAttributes:defaultAttributes range:afterFractionRange];
        }
    }
    else {
        [attributedString setAttributes:defaultAttributes
                                  range:NSMakeRange(0, localCurrencyFormatted.length)];
    }
    [attributedString endEditing];

    return [attributedString copy];
}

#pragma mark - Private

+ (NSAttributedString *)attributedStringForLocalCurrencyFormatted:(NSString *)localCurrencyFormatted {
    return [self attributedStringForLocalCurrencyFormatted:localCurrencyFormatted textColor:[UIColor dw_darkTitleColor]];
}

+ (nullable NSString *)rawAmountStringFromFormattedString:(NSString *)formattedString
                                          numberFormatter:(NSNumberFormatter *)numberFormatter
                                                validator:(DWAmountInputValidator *)validator {
    NSLocale *locale = [NSLocale currentLocale];
    return [self rawAmountStringFromFormattedString:formattedString
                                    numberFormatter:numberFormatter
                                          validator:validator
                                             locale:locale];
}

+ (nullable NSString *)rawAmountStringFromFormattedString:(NSString *)formattedString
                                          numberFormatter:(NSNumberFormatter *)numberFormatter
                                                validator:(DWAmountInputValidator *)validator
                                                   locale:(NSLocale *)locale {
    NSNumber *number = [numberFormatter numberFromString:formattedString];
    NSParameterAssert(number);
    if (!number) {
        return nil;
    }

    NSString *result = [validator stringFromNumberUsingInternalFormatter:number];

    return result;
}

+ (NSString *)formattedAmountWithInputString:(NSString *)inputString
                             formattedString:(NSString *)formattedString
                             numberFormatter:(NSNumberFormatter *)numberFormatter {
    NSLocale *locale = [NSLocale currentLocale];
    return [self formattedAmountWithInputString:inputString
                                formattedString:formattedString
                                numberFormatter:numberFormatter
                                         locale:locale];
}

+ (NSString *)formattedAmountWithInputString:(NSString *)inputString
                             formattedString:(NSString *)formattedString
                             numberFormatter:(NSNumberFormatter *)numberFormatter
                                      locale:(NSLocale *)locale {
    NSAssert(numberFormatter.numberStyle == NSNumberFormatterCurrencyStyle, @"Invalid number formatter");

    NSString *decimalSeparator = locale.decimalSeparator;
    NSAssert([numberFormatter.decimalSeparator isEqualToString:decimalSeparator], @"Custom decimal separators are not supported");
    NSUInteger inputSeparatorIndex = [inputString rangeOfString:decimalSeparator].location;
    if (inputSeparatorIndex == NSNotFound) {
        return formattedString;
    }

    NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];

    NSString *currencySymbol = [self currencySymbolFromFormattedString:formattedString numberFormatter:numberFormatter];
    if (currencySymbol.length == 0) {
        // handle Axe number formatter as it has "AXE NARROW_NBSP" as currency symbol
        if ([numberFormatter.currencySymbol rangeOfString:AXE].location != NSNotFound) {
            currencySymbol = numberFormatter.currencySymbol;
        }
        else {
            // special case for countries with empty currency symbol (Cape Verde so far)
            return formattedString;
        }
    }

    NSRange currencySymbolRange = [formattedString rangeOfString:currencySymbol];
    NSAssert(currencySymbolRange.location != NSNotFound, @"Invalid formatted string");

    BOOL isCurrencySymbolAtTheBeginning = currencySymbolRange.location == 0;
    NSString *currencySymbolNumberSeparator = nil;
    if (isCurrencySymbolAtTheBeginning) {
        currencySymbolNumberSeparator = [formattedString substringWithRange:NSMakeRange(currencySymbolRange.length, 1)];
    }
    else {
        currencySymbolNumberSeparator = [formattedString substringWithRange:NSMakeRange(currencySymbolRange.location - 1, 1)];
    }
    if ([currencySymbolNumberSeparator rangeOfCharacterFromSet:whitespaceCharacterSet].location == NSNotFound) {
        currencySymbolNumberSeparator = @"";
    }

    NSString *formattedStringWithoutCurrency =
        [[formattedString stringByReplacingCharactersInRange:currencySymbolRange withString:@""]
            stringByTrimmingCharactersInSet:whitespaceCharacterSet];

    NSString *inputFractionPartWithSeparator = [inputString substringFromIndex:inputSeparatorIndex];
    NSUInteger formattedSeparatorIndex = [formattedStringWithoutCurrency rangeOfString:decimalSeparator].location;
    if (formattedSeparatorIndex == NSNotFound) {
        formattedSeparatorIndex = formattedStringWithoutCurrency.length;
        formattedStringWithoutCurrency = [formattedStringWithoutCurrency stringByAppendingString:decimalSeparator];
    }
    NSRange formattedFractionPartRange = NSMakeRange(formattedSeparatorIndex, formattedStringWithoutCurrency.length - formattedSeparatorIndex);

    NSString *formattedStringWithFractionInput = [formattedStringWithoutCurrency stringByReplacingCharactersInRange:formattedFractionPartRange withString:inputFractionPartWithSeparator];

    NSString *result = nil;
    if (isCurrencySymbolAtTheBeginning) {
        result = [NSString stringWithFormat:@"%@%@%@",
                                            currencySymbol,
                                            currencySymbolNumberSeparator,
                                            formattedStringWithFractionInput];
    }
    else {
        result = [NSString stringWithFormat:@"%@%@%@",
                                            formattedStringWithFractionInput,
                                            currencySymbolNumberSeparator,
                                            currencySymbol];
    }

    return result;
}

/**
 Extract currency symbol from string formatted by number formatter

 @discussion By default, `NSNumberFormatter` uses `[NSLocale currentLocale]` to determine `currencySymbol`.
 When we manually set `currencyCode`, `currencySymbol` is no longer valid.
 For instance, if user has *_RU locale: `numberFormatter.currencySymbol` is RUB but formatted string is "1.23 US$",
 because he selected US Dollars as local price. So we have to manually parse the correct currency symbol.
 */
+ (nullable NSString *)currencySymbolFromFormattedString:(NSString *)formattedString numberFormatter:(NSNumberFormatter *)numberFormatter {
    NSString *const CurrencySymbol = @"¤";

    NSString *format = numberFormatter.positiveFormat; // since we work only with positive numbers
    NSRange currencySymbolRange = [format rangeOfString:CurrencySymbol];
    NSAssert(currencySymbolRange.location != NSNotFound, @"Invalid formatted string");
    if (currencySymbolRange.location == NSNotFound) {
        return nil;
    }

    BOOL isCurrencySymbolAtTheBeginning = currencySymbolRange.location == 0;
    BOOL isCurrencySymbolAtTheEnd = (currencySymbolRange.location + currencySymbolRange.length) == format.length;

    if (!isCurrencySymbolAtTheBeginning && !isCurrencySymbolAtTheEnd) {
        // special case to deal with RTL languages
        if ([format hasPrefix:@"\U0000200e"] || [format hasPrefix:@"\U0000200f"]) {
            return numberFormatter.currencySymbol;
        }
    }

    NSMutableCharacterSet *digitAndWhitespaceSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    [digitAndWhitespaceSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];

    NSArray<NSString *> *separatedString = [formattedString componentsSeparatedByCharactersInSet:digitAndWhitespaceSet];
    if (isCurrencySymbolAtTheBeginning) {
        return separatedString.firstObject;
    }
    else {
        return separatedString.lastObject;
    }
}

@end

NS_ASSUME_NONNULL_END
