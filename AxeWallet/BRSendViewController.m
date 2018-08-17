//
//  BRSendViewController.m
//  BreadWallet
//
//  Created by Aaron Voisine on 5/8/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BRSendViewController.h"
#import "BRRootViewController.h"
#import "BRAmountViewController.h"
#import "BRSettingsViewController.h"
#import "BRBubbleView.h"
#import "BRWalletManager.h"
#import "BRPeerManager.h"
#import "BRPaymentRequest.h"
#import "BRPaymentProtocol.h"
#import "BRKey.h"
#import "BRTransaction.h"
#import "NSString+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"
#import "NSString+Axe.h"
#import "NSData+Axe.h"
#import "NSData+Bitcoin.h"
#import "BREventManager.h"
#import "FBShimmeringView.h"
#import "MBProgressHUD.h"
#import "DSShapeshiftManager.h"
#import "BRBIP32Sequence.h"
#import "BRQRScanViewController.h"
#import "BRQRScanViewModel.h"

#define SCAN_TIP      NSLocalizedString(@"Scan someone else's QR code to get their axe or bitcoin address. "\
"You can send a payment to anyone with an address.", nil)
#define CLIPBOARD_TIP NSLocalizedString(@"Axe addresses can also be copied to the clipboard. "\
"An axe address always starts with 'P' or '7'.", nil)

#define LOCK @"\xF0\x9F\x94\x92" // unicode lock symbol U+1F512 (utf-8)
#define REDX @"\xE2\x9D\x8C"     // unicode cross mark U+274C, red x emoji (utf-8)
#define NBSP @"\xC2\xA0"         // no-break space (utf-8)

#define SEND_INSTANTLY_KEY @"SEND_INSTANTLY_KEY"

static NSString *sanitizeString(NSString *s)
{
    NSMutableString *sane = [NSMutableString stringWithString:(s) ? s : @""];
    
    CFStringTransform((CFMutableStringRef)sane, NULL, kCFStringTransformToUnicodeName, NO);
    return sane;
}

@interface BRSendViewController () <BRQRScanViewModelDelegate>

@property (nonatomic, assign) BOOL clearClipboard, useClipboard, showTips, showBalance, canChangeAmount, sendInstantly;
@property (nonatomic, strong) BRTransaction *sweepTx;
@property (nonatomic, strong) BRPaymentProtocolRequest *request, *shapeshiftRequest;
@property (nonatomic, strong) NSString *scheme;
@property (nonatomic, strong) DSShapeshiftEntity * associatedShapeshift;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) uint64_t amount;
@property (nonatomic, strong) NSString *okAddress, *okIdentity;
@property (nonatomic, strong) BRBubbleView *tipView;

@property (nonatomic, strong) IBOutlet UILabel *sendLabel;
@property (nonatomic, strong) IBOutlet UISwitch *instantSwitch;
@property (nonatomic, strong) IBOutlet UIButton *scanButton, *clipboardButton;
@property (nonatomic, strong) IBOutlet UIView * shapeshiftView;
@property (nonatomic, strong) IBOutlet UILabel * shapeshiftLabel;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint * NFCWidthConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint * leftOfNFCButtonWhitespaceConstraint;

@end

@implementation BRSendViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // TODO: XXX redesign page with round buttons like the iOS power down screen... apple watch also has round buttons
    self.scanButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.clipboardButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.scanButton.titleLabel.adjustsLetterSpacingToFitWidth = YES;
    self.clipboardButton.titleLabel.adjustsLetterSpacingToFitWidth = YES;
#pragma clang diagnostic pop
    
    FBShimmeringView *shimmeringView = [[FBShimmeringView alloc] initWithFrame:CGRectMake(0, self.shapeshiftView.frame.origin.y, self.view.frame.size.width, self.shapeshiftView.frame.size.height)];
    [self.view addSubview:shimmeringView];
    [self.shapeshiftView removeFromSuperview];
    [shimmeringView addSubview:self.shapeshiftView];
    shimmeringView.contentView = self.shapeshiftView;
    // Start shimmering.
    shimmeringView.shimmering = YES;
    shimmeringView.shimmeringSpeed = 5;
    shimmeringView.shimmeringDirection = FBShimmerDirectionUp;
    shimmeringView.shimmeringPauseDuration = 0.0;
    shimmeringView.shimmeringHighlightLength = 1.0f;
    shimmeringView.shimmeringAnimationOpacity = 0.8;
    self.shapeshiftView = shimmeringView;
    
    FBShimmeringView *shimmeringInnerLabelView = [[FBShimmeringView alloc] initWithFrame:self.shapeshiftLabel.frame];
    [self.shapeshiftLabel removeFromSuperview];
    [shimmeringInnerLabelView addSubview:self.shapeshiftLabel];
    shimmeringInnerLabelView.contentView = self.shapeshiftLabel;
    
    shimmeringInnerLabelView.shimmering = YES;
    shimmeringInnerLabelView.shimmeringSpeed = 100;
    shimmeringInnerLabelView.shimmeringPauseDuration = 0.8;
    shimmeringInnerLabelView.shimmeringAnimationOpacity = 0.2;
    [self.shapeshiftView addSubview:shimmeringInnerLabelView];
    NSArray * shapeshiftsInProgress = [DSShapeshiftEntity shapeshiftsInProgress];
    if (![shapeshiftsInProgress count]) {
        
        self.shapeshiftView.hidden = TRUE;
    } else {
        for (DSShapeshiftEntity * shapeshift in shapeshiftsInProgress) {
            [shapeshift transaction];
            [self startObservingShapeshift:shapeshift];
        }
    }
    
    self.sendInstantly = [[NSUserDefaults standardUserDefaults] boolForKey:SEND_INSTANTLY_KEY];
    [self.instantSwitch setOn:self.sendInstantly];
    BOOL hasNFC = NO;
    if (@available(iOS 11.0, *)) {
        if ([NFCNDEFReaderSession readingAvailable]) {
            hasNFC = YES;
        }
    }
    
    if (!hasNFC) {
        [self.NFCWidthConstraint setConstant:0];
        [self.leftOfNFCButtonWhitespaceConstraint setConstant:0];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self cancel:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self hideTips];
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    
}

-(BOOL)processURLAddressList:(NSURL*)url {
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    if (! [self.url isEqual:url]) {
        self.url = url;
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:NSLocalizedString(@"copy wallet addresses to clipboard?", nil)
                                     message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* cancelButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"cancel", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                           if (self.url) {
                                               self.clearClipboard = YES;
                                               [self handleURL:self.url];
                                           }
                                           else [self cancelOrChangeAmount];
                                       }];
        UIAlertAction* copyButton = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"copy", nil)
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action) {
                                         [self handleURL:self.url];
                                     }];
        
        [alert addAction:cancelButton];
        [alert addAction:copyButton];
        [self presentViewController:alert animated:YES completion:nil];
        return NO;
    }
    else {
        [UIPasteboard generalPasteboard].string =
        [[[manager.wallet.allReceiveAddresses
           setByAddingObjectsFromSet:manager.wallet.allChangeAddresses]
          objectsPassingTest:^BOOL(id obj, BOOL *stop) {
              return [manager.wallet addressIsUsed:obj];
          }].allObjects componentsJoinedByString:@"\n"];
        
        return YES;
        
    }
}

- (void)handleURL:(NSURL *)url
{
    [BREventManager saveEvent:@"send:handle_url"
               withAttributes:@{@"scheme": (url.scheme ? url.scheme : @"(null)"),
                                @"host": (url.host ? url.host : @"(null)"),
                                @"path": (url.path ? url.path : @"(null)")}];
    
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    if ([url.scheme isEqual:@"axewallet"]) {
        if ([url.host isEqual:@"scanqr"] || [url.path isEqual:@"/scanqr"]) { // scan qr
            [self scanQR:self.scanButton];
        } else if ([url.host hasPrefix:@"request"] || [url.path isEqual:@"/request"]) {
            NSArray * array = [url.host componentsSeparatedByString:@"&"];
            NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
            for (NSString * param in array) {
                NSArray * paramArray = [param componentsSeparatedByString:@"="];
                if ([paramArray count] == 2) {
                    [dictionary setObject:paramArray[1] forKey:paramArray[0]];
                }
            }
            
            if (dictionary[@"request"] && dictionary[@"sender"] && (!dictionary[@"account"] || [dictionary[@"account"] isEqualToString:@"0"])) {
                if ([dictionary[@"request"] isEqualToString:@"masterPublicKey"]) {
                    [manager authenticateWithPrompt:[NSString stringWithFormat:NSLocalizedString(@"Application %@ would like to receive your Master Public Key.  This can be used to keep track of your wallet, this can not be used to move your Axe.",nil),dictionary[@"sender"]] andTouchId:NO alertIfLockout:YES completion:^(BOOL authenticatedOrSuccess,BOOL cancelled) {
                        if (authenticatedOrSuccess) {
                            BRBIP32Sequence *seq = [BRBIP32Sequence new];
                            NSString * masterPublicKeySerialized = [seq serializedMasterPublicKey:manager.extendedBIP44PublicKey depth:BIP44_PURPOSE_ACCOUNT_DEPTH];
                            NSString * masterPublicKeyNoPurposeSerialized = [seq serializedMasterPublicKey:manager.extendedBIP32PublicKey depth:BIP32_PURPOSE_ACCOUNT_DEPTH];
                            NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://callback=%@&masterPublicKeyBIP32=%@&masterPublicKeyBIP44=%@&account=%@&source=axewallet",dictionary[@"sender"],dictionary[@"request"],masterPublicKeyNoPurposeSerialized,masterPublicKeySerialized,@"0"]];
                            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                                
                            }];
                        }
                    }];
                } else if ([dictionary[@"request"] isEqualToString:@"address"]) {
                    [manager authenticateWithPrompt:[NSString stringWithFormat:NSLocalizedString(@"Application %@ is requesting an address so it can pay you.  Would you like to authorize this?",nil),dictionary[@"sender"]] andTouchId:NO alertIfLockout:YES completion:^(BOOL authenticatedOrSuccess,BOOL cancelled) {
                        if (authenticatedOrSuccess) {
                            NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://callback=%@&address=%@&source=axewallet",dictionary[@"sender"],dictionary[@"request"],manager.wallet.receiveAddress]];
                            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                                
                            }];
                        }
                    }];
                }
                
            }
        } else if ([url.host hasPrefix:@"pay"] || [url.path isEqual:@"/pay"]) {
            NSMutableArray * array = [[url.host componentsSeparatedByString:@"&"] mutableCopy];
            NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
            for (NSString * param in array) {
                NSArray * paramArray = [param componentsSeparatedByString:@"="];
                if ([paramArray count] == 2) {
                    [dictionary setObject:paramArray[1] forKey:paramArray[0]];
                }
            }
            if (dictionary[@"pay"] && dictionary[@"sender"]) {
                if (dictionary[@"label"]) [dictionary removeObjectForKey:@"label"];
                NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"axe:%@",dictionary[@"pay"]]];
                NSMutableArray *queryItems = [NSMutableArray array];
                NSURLQueryItem *label = [NSURLQueryItem queryItemWithName:@"label" value:[NSString stringWithFormat:NSLocalizedString(@"Application %@ is requesting a payment to",nil),[dictionary[@"sender"] capitalizedString]]];
                [queryItems addObject:label];
                for (NSString *key in dictionary) {
                    if ([key isEqualToString:@"label"]) continue;
                    [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:dictionary[key]]];
                }
                components.queryItems = queryItems;
                NSURL * paymentURL = components.URL;
                [self confirmRequest:[BRPaymentRequest requestWithURL:paymentURL]];
            }
        }
    }
    else if ([url.scheme isEqual:@"axe"]) {
        [self confirmRequest:[BRPaymentRequest requestWithURL:url]];
    }
    else {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:NSLocalizedString(@"unsupported url", nil)
                                     message:url.absoluteString
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okButton = [UIAlertAction
                                   actionWithTitle:@"ok"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                   }];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)handleFile:(NSData *)file
{
    BRPaymentProtocolRequest *request = [BRPaymentProtocolRequest requestWithData:file];
    
    if (request) {
        [self confirmProtocolRequest:request];
        return;
    }
    
    // TODO: reject payments that don't match requested amounts/scripts, implement refunds
    BRPaymentProtocolPayment *payment = [BRPaymentProtocolPayment paymentWithData:file];
    
    if (payment.transactions.count > 0) {
        for (BRTransaction *tx in payment.transactions) {
            [(id)self.parentViewController.parentViewController startActivityWithTimeout:30];
            
            [[BRPeerManager sharedInstance] publishTransaction:tx completion:^(NSError *error) {
                [(id)self.parentViewController.parentViewController stopActivityWithSuccess:(! error)];
                
                if (error) {
                    UIAlertController * alert = [UIAlertController
                                                 alertControllerWithTitle:NSLocalizedString(@"couldn't transmit payment to axe network", nil)
                                                 message:error.localizedDescription
                                                 preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction* okButton = [UIAlertAction
                                               actionWithTitle:@"ok"
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction * action) {
                                               }];
                    [alert addAction:okButton];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                
                [self.view addSubview:[[[BRBubbleView
                                         viewWithText:(payment.memo.length > 0 ? payment.memo : NSLocalizedString(@"Received", nil))
                                         center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                       popOutAfterDelay:(payment.memo.length > 0 ? 3.0 : 2.0)]];
            }];
        }
        
        return;
    }
    
    BRPaymentProtocolACK *ack = [BRPaymentProtocolACK ackWithData:file];
    
    if (ack) {
        if (ack.memo.length > 0) {
            [self.view addSubview:[[[BRBubbleView viewWithText:ack.memo
                                                        center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                   popOutAfterDelay:3.0]];
        }
        
        return;
    }
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"unsupported or corrupted document", nil)
                                 message:@""
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:@"ok"
                               style:UIAlertActionStyleCancel
                               handler:^(UIAlertAction * action) {
                               }];
    [alert addAction:okButton];
    [self presentViewController:alert animated:YES completion:nil];
    
}


// generate a description of a transaction so the user can review and decide whether to confirm or cancel
- (NSString *)promptForAmount:(uint64_t)amount
                          fee:(uint64_t)fee
                      address:(NSString *)address
                         name:(NSString *)name
                         memo:(NSString *)memo
                     isSecure:(BOOL)isSecure
                localCurrency:(NSString *)localCurrency
          localCurrencyAmount:(NSString *)localCurrencyAmount
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSString *prompt = (isSecure && name.length > 0) ? LOCK @" " : @"";
    
    //BUG: XXX limit the length of name and memo to avoid having the amount clipped
    if (! isSecure && self.request.errorMessage.length > 0) prompt = [prompt stringByAppendingString:REDX @" "];
    if (name.length > 0) prompt = [prompt stringByAppendingString:sanitizeString(name)];
    if (! isSecure && prompt.length > 0) prompt = [prompt stringByAppendingString:@"\n"];
    if (! isSecure || prompt.length == 0) prompt = [prompt stringByAppendingString:address];
    if (memo.length > 0) prompt = [prompt stringByAppendingFormat:@"\n\n%@", sanitizeString(memo)];
    prompt = [prompt stringByAppendingFormat:NSLocalizedString(@"\n\n     amount %@ (%@)", nil),
              [manager stringForAxeAmount:amount - fee], [manager localCurrencyStringForAxeAmount:amount - fee]];
    
    if (localCurrency && localCurrencyAmount && ![localCurrency isEqualToString:manager.localCurrencyCode]) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.currencyCode = localCurrency;
        numberFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        NSNumber *localAmount = [NSDecimalNumber decimalNumberWithString:localCurrencyAmount];
        NSString *requestedAmount = [numberFormatter stringFromNumber:localAmount];
        prompt = [prompt stringByAppendingFormat:NSLocalizedString(@"\n(local requested amount: %@)", nil), requestedAmount];
    }
    
    if (fee > 0) {
        prompt = [prompt stringByAppendingFormat:NSLocalizedString(@"\nnetwork fee +%@ (%@)", nil),
                  [manager stringForAxeAmount:fee], [manager localCurrencyStringForAxeAmount:fee]];
        prompt = [prompt stringByAppendingFormat:NSLocalizedString(@"\n         total %@ (%@)", nil),
                  [manager stringForAxeAmount:amount], [manager localCurrencyStringForAxeAmount:amount]];
    }
    
    return prompt;
}

- (void)confirmRequest:(BRPaymentRequest *)request
{
    if (! request.isValid) {
        if ([request.paymentAddress isValidAxePrivateKey] || [request.paymentAddress isValidAxeBIP38Key]) {
            [self confirmSweep:request.paymentAddress];
        }
        else {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"not a valid axe or bitcoin address", nil)
                                         message:request.paymentAddress
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:@"ok"
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                       }];
            [alert addAction:okButton];
            [self presentViewController:alert animated:YES completion:nil];
            [self cancel:nil];
        }
    }
    else if (request.r.length > 0) { // payment protocol over HTTP
        [(id)self.parentViewController.parentViewController startActivityWithTimeout:20.0];
        
        [BRPaymentRequest fetch:request.r scheme:request.scheme timeout:20.0 completion:^(BRPaymentProtocolRequest *req, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [(id)self.parentViewController.parentViewController stopActivityWithSuccess:(! error)];
                
                if (error && ! ([request.paymentAddress isValidBitcoinAddress] || [request.paymentAddress isValidAxeAddress])) {
                    UIAlertController * alert = [UIAlertController
                                                 alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                                 message:error.localizedDescription
                                                 preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction* okButton = [UIAlertAction
                                               actionWithTitle:@"ok"
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction * action) {
                                               }];
                    [alert addAction:okButton];
                    [self presentViewController:alert animated:YES completion:nil];
                    [self cancel:nil];
                }
                else [self confirmProtocolRequest:(error) ? request.protocolRequest : req];
            });
        }];
    }
    else [self confirmProtocolRequest:request.protocolRequest currency:request.scheme associatedShapeshift:nil wantsInstant:request.wantsInstant requiresInstantValue:request.instantValueRequired localCurrency:request.currency localCurrencyAmount:request.currencyAmount];
}

- (void)confirmProtocolRequest:(BRPaymentProtocolRequest *)protoReq {
    [self confirmProtocolRequest:protoReq currency:@"axe" associatedShapeshift:nil localCurrency:nil localCurrencyAmount:nil];
}

- (void)confirmProtocolRequest:(BRPaymentProtocolRequest *)protoReq currency:(NSString*)currency associatedShapeshift:(DSShapeshiftEntity*)shapeshift localCurrency:(NSString *)localCurrency localCurrencyAmount:(NSString *)localCurrencyAmount
{
    [self confirmProtocolRequest:protoReq currency:currency associatedShapeshift:shapeshift wantsInstant:self.sendInstantly requiresInstantValue:FALSE localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
}

- (void)confirmProtocolRequest:(BRPaymentProtocolRequest *)protoReq currency:(NSString*)currency associatedShapeshift:(DSShapeshiftEntity*)shapeshift wantsInstant:(BOOL)wantsInstant requiresInstantValue:(BOOL)requiresInstantValue localCurrency:(NSString *)localCurrency localCurrencyAmount:(NSString *)localCurrencyAmount
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    BRTransaction *tx = nil;
    uint64_t amount = 0, fee = 0;
    BOOL valid = protoReq.isValid, outputTooSmall = NO;
    UIViewController * viewControllerToShowAlert = self;
    if (self.presentedViewController && [self.presentedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController * presentedController = (UINavigationController*)self.presentedViewController;
        viewControllerToShowAlert = presentedController.topViewController;
    }
    if (! valid && [protoReq.errorMessage isEqual:NSLocalizedString(@"request expired", nil)]) {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:NSLocalizedString(@"bad payment request", nil)
                                     message:protoReq.errorMessage
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okButton = [UIAlertAction
                                   actionWithTitle:@"ok"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                   }];
        [alert addAction:okButton];
        [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
        [self cancel:nil];
        return;
    }
    
    //TODO: check for duplicates of already paid requests
    
    if (self.amount == 0) {
        for (NSNumber *outputAmount in protoReq.details.outputAmounts) {
            if (outputAmount.unsignedLongLongValue > 0 && outputAmount.unsignedLongLongValue < TX_MIN_OUTPUT_AMOUNT) {
                outputTooSmall = YES;
            }
            amount += outputAmount.unsignedLongLongValue;
        }
    }
    else amount = self.amount;
    
    if ([currency isEqualToString:@"axe"]) {
        NSString *address = [NSString addressWithScriptPubKey:protoReq.details.outputScripts.firstObject];
        if ([manager.wallet containsAddress:address]) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:@""
                                         message:NSLocalizedString(@"this payment address is already in your wallet", nil)
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:@"ok"
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                       }];
            [alert addAction:okButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            [self cancel:nil];
            return;
        }
        else if (! [self.okAddress isEqual:address] && [manager.wallet addressIsUsed:address] &&
                 [[UIPasteboard generalPasteboard].string isEqual:address]) {
            self.request = protoReq;
            self.scheme = currency;
            self.okAddress = address;
            self.associatedShapeshift = shapeshift;
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"WARNING", nil)
                                         message:NSLocalizedString(@"\nADDRESS ALREADY USED\naxe addresses are intended for single use only\n\n"
                                                                   "re-use reduces privacy for both you and the recipient and can result in loss if "
                                                                   "the recipient doesn't directly control the address", nil)
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* cancelButton = [UIAlertAction
                                           actionWithTitle:@"cancel"
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                               [self cancelOrChangeAmount];
                                           }];
            UIAlertAction* ignoreButton = [UIAlertAction
                                           actionWithTitle:@"ignore"
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * action) {
                                               [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                           }];
            [alert addAction:ignoreButton];
            [alert addAction:cancelButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            return;
        } else if (wantsInstant && !self.sendInstantly) {
            self.request = protoReq;
            self.scheme = currency;
            self.associatedShapeshift = shapeshift;
            
            if (requiresInstantValue) {
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"instant payment", nil)
                                             message:NSLocalizedString(@"this request requires an instant payment but you have disabled instant payments",
                                                                       nil)
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* ignoreButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"cancel", nil)
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   
                                               }];
                UIAlertAction* enableButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"enable", nil)
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   self.sendInstantly = TRUE;
                                                   [self.instantSwitch setOn:TRUE animated:TRUE];
                                                   [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift wantsInstant:TRUE requiresInstantValue:TRUE localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                               }];
                
                [alert addAction:ignoreButton];
                [alert addAction:enableButton];
                [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            } else {
                
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"instant payment", nil)
                                             message:NSLocalizedString(@"request is for an instant payment but you have disabled instant payments",
                                                                       nil)
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* ignoreButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"ignore", nil)
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                               }];
                UIAlertAction* enableButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"enable", nil)
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   self.sendInstantly = TRUE;
                                                   [self.instantSwitch setOn:TRUE animated:TRUE];
                                                   [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift wantsInstant:TRUE requiresInstantValue:requiresInstantValue localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                               }];
                
                [alert addAction:ignoreButton];
                [alert addAction:enableButton];
                [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            }
            return;
            
        } else if (amount > manager.wallet.balance && amount != UINT64_MAX) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"insufficient funds", nil)
                                         message:nil
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                       }];
            
            [alert addAction:okButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            [self cancel:nil];
            return;
        } else if (wantsInstant && ([manager.wallet maxOutputAmountWithConfirmationCount:IX_PREVIOUS_CONFIRMATIONS_NEEDED usingInstantSend:TRUE] < amount)) {
            self.request = protoReq;
            self.scheme = currency;
            self.associatedShapeshift = shapeshift;
            if (requiresInstantValue) {
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"instant payment", nil)
                                             message:NSLocalizedString(@"This request requires an instant payment but you do not have enough inputs with 6 confirmations required by InstantSend, you may ask the merchant to accept a normal transaction or wait a few minutes.",
                                                                       nil)
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* cancelButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"cancel", nil)
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [self cancelOrChangeAmount];
                                               }];
                UIAlertAction* retryButton = [UIAlertAction
                                              actionWithTitle:NSLocalizedString(@"retry", nil)
                                              style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction * action) {
                                                  [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift wantsInstant:wantsInstant requiresInstantValue:requiresInstantValue localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                              }];
                
                [alert addAction:cancelButton];
                [alert addAction:retryButton];
                [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"instant payment", nil)
                                             message:NSLocalizedString(@"InstantSend requires enough inputs with 6 confirmations, send anyways as regular transaction?",
                                                                       nil)
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* cancelButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"cancel", nil)
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction * action) {
                                                   [self cancelOrChangeAmount];
                                               }];
                UIAlertAction* enableButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"send", nil)
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift wantsInstant:FALSE requiresInstantValue:requiresInstantValue localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                               }];
                
                [alert addAction:cancelButton];
                [alert addAction:enableButton];
                [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
                return;
            }
        } else if (protoReq.errorMessage.length > 0 && protoReq.commonName.length > 0 &&
                   ! [self.okIdentity isEqual:protoReq.commonName]) {
            self.request = protoReq;
            self.scheme = currency;
            self.okIdentity = protoReq.commonName;
            self.associatedShapeshift = shapeshift;
            
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"payee identity isn't certified", nil)
                                         message:protoReq.errorMessage
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* ignoreButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ignore", nil)
                                           style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction * action) {
                                               [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                           }];
            UIAlertAction* cancelButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"cancel", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                               [self cancelOrChangeAmount];
                                           }];
            
            [alert addAction:ignoreButton];
            [alert addAction:cancelButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            
            return;
        }
        else if (amount == 0 || amount == UINT64_MAX) {
            self.request = protoReq;
            self.scheme = currency;
            self.associatedShapeshift = shapeshift;
            [self updateTitleView];
            [self performSegueWithIdentifier:@"SendAmountSegue" sender:self];
            return;
        }
        else if (amount < TX_MIN_OUTPUT_AMOUNT) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                         message:[NSString stringWithFormat:NSLocalizedString(@"axe payments can't be less than %@", nil),
                                                  [manager stringForAxeAmount:TX_MIN_OUTPUT_AMOUNT]]
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                           
                                       }];
            
            
            [alert addAction:okButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            [self cancel:nil];
            return;
        }
        else if (outputTooSmall) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                         message:[NSString stringWithFormat:NSLocalizedString(@"axe transaction outputs can't be less than %@",
                                                                                              nil), [manager stringForAxeAmount:TX_MIN_OUTPUT_AMOUNT]]
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                           
                                       }];
            
            
            [alert addAction:okButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            [self cancel:nil];
            return;
        }
        
        self.request = protoReq;
        self.scheme = @"axe";
        
        if (self.amount == 0) {
            
            if (shapeshift) {
                tx = [manager.wallet transactionForAmounts:protoReq.details.outputAmounts
                                           toOutputScripts:protoReq.details.outputScripts withFee:YES isInstant:wantsInstant toShapeshiftAddress:shapeshift.withdrawalAddress];
                tx.associatedShapeshift = shapeshift;
            } else {
                tx = [manager.wallet transactionForAmounts:protoReq.details.outputAmounts
                                           toOutputScripts:protoReq.details.outputScripts withFee:YES isInstant:wantsInstant toShapeshiftAddress:nil];
            }
        }
        else {
            if (shapeshift) {
                tx = [manager.wallet transactionForAmounts:@[@(self.amount)]
                                           toOutputScripts:@[protoReq.details.outputScripts.firstObject] withFee:YES isInstant:wantsInstant toShapeshiftAddress:shapeshift.withdrawalAddress];
                tx.associatedShapeshift = shapeshift;
            } else {
                tx = [manager.wallet transactionForAmounts:@[@(self.amount)]
                                           toOutputScripts:@[protoReq.details.outputScripts.firstObject] withFee:YES isInstant:wantsInstant toShapeshiftAddress:nil];
            }
        }
        
        if (tx) {
            amount = [manager.wallet amountSentByTransaction:tx] - [manager.wallet amountReceivedFromTransaction:tx];
            fee = [manager.wallet feeForTransaction:tx];
        }
        else {
            BRTransaction * tempTx = [manager.wallet transactionFor:manager.wallet.balance
                                                                 to:address withFee:NO];
            fee = [manager.wallet feeForTxSize:tempTx.size isInstant:self.sendInstantly inputCount:tempTx.inputHashes.count];
            fee += (manager.wallet.balance - amount) % 100;
            amount += fee;
        }
        
        for (NSData *script in protoReq.details.outputScripts) {
            NSString *addr = [NSString addressWithScriptPubKey:script];
            
            if (! addr) addr = NSLocalizedString(@"unrecognized address", nil);
            if ([address rangeOfString:addr].location != NSNotFound) continue;
            address = [address stringByAppendingFormat:@"%@%@", (address.length > 0) ? @", " : @"", addr];
        }
        
        NSString *prompt = [self promptForAmount:amount
                                             fee:fee
                                         address:address
                                            name:protoReq.commonName
                                            memo:protoReq.details.memo
                                        isSecure:(valid && ! [protoReq.pkiType isEqual:@"none"])
                                   localCurrency:localCurrency
                             localCurrencyAmount:localCurrencyAmount];
        
        // to avoid the frozen pincode keyboard bug, we need to make sure we're scheduled normally on the main runloop
        // rather than a dispatch_async queue
        CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes, ^{
            [self confirmTransaction:tx toAddress:address withPrompt:prompt forAmount:amount localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
        });
    } else if ([currency isEqualToString:@"bitcoin"]) {
        NSString *address = [NSString bitcoinAddressWithScriptPubKey:protoReq.details.outputScripts.firstObject];
        if (protoReq.errorMessage.length > 0 && protoReq.commonName.length > 0 &&
            ! [self.okIdentity isEqual:protoReq.commonName]) {
            self.request = protoReq;
            self.shapeshiftRequest = protoReq;
            self.scheme = currency;
            self.associatedShapeshift = shapeshift;
            self.okIdentity = protoReq.commonName;
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"payee identity isn't certified", nil)
                                         message:protoReq.errorMessage
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* ignoreButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ignore", nil)
                                           style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction * action) {
                                               [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                           }];
            UIAlertAction* cancelButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"cancel", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                               [self cancelOrChangeAmount];
                                           }];
            
            [alert addAction:ignoreButton];
            [alert addAction:cancelButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            return;
        }
        else if (amount == 0 || amount == UINT64_MAX) {
            self.scheme = currency;
            self.request = protoReq;
            self.shapeshiftRequest = protoReq;
            self.associatedShapeshift = shapeshift;
            [self performSegueWithIdentifier:@"SendAmountSegue" sender:self];
            return;
        }
        else if (amount < TX_MIN_OUTPUT_AMOUNT) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                         message:[NSString stringWithFormat:NSLocalizedString(@"bitcoin payments can't be less than %@", nil),
                                                  [manager stringForBitcoinAmount:TX_MIN_OUTPUT_AMOUNT]]
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                           
                                       }];
            
            
            [alert addAction:okButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            [self cancel:nil];
            return;
        }
        else if (outputTooSmall) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                         message:[NSString stringWithFormat:NSLocalizedString(@"axe transaction outputs can't be less than %@",
                                                                                              nil), [manager stringForAxeAmount:TX_MIN_OUTPUT_AMOUNT]]
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                           
                                       }];
            
            
            [alert addAction:okButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            [self cancel:nil];
            return;
        }
        self.request = protoReq;
        self.shapeshiftRequest = protoReq;
        self.scheme = currency;
        [self amountViewController:nil shapeshiftBitcoinAmount:amount approximateAxeAmount:1.03*amount/manager.bitcoinAxePrice.doubleValue];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"SendAmountSegue"]) {
        BRAmountViewController *amountController = (BRAmountViewController *)((UINavigationController*)segue.destinationViewController).topViewController;
        
        amountController.delegate = self;
        if ([self.scheme isEqualToString:@"bitcoin"]) {
            amountController.usingShapeshift = TRUE;
            amountController.to = sanitizeString(self.associatedShapeshift.withdrawalAddress);
        } else {
            NSString *address = [NSString addressWithScriptPubKey:self.request.details.outputScripts.firstObject];
            if (self.request.commonName.length > 0) {
                if (self.request.isValid && ! [self.request.pkiType isEqual:@"none"]) {
                    amountController.to = [LOCK @" " stringByAppendingString:sanitizeString(self.request.commonName)];
                }
                else if (self.request.errorMessage.length > 0) {
                    amountController.to = [REDX @" " stringByAppendingString:sanitizeString(self.request.commonName)];
                }
                else amountController.to = sanitizeString(self.request.commonName);
            }
            else amountController.to = address;
        }
    }
}

-(void)insufficientFundsForTransaction:(BRTransaction *)tx forAmount:(uint64_t)amount localCurrency:(NSString *)localCurrency localCurrencyAmount:(NSString *)localCurrencyAmount {
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    uint64_t fuzz = [manager amountForLocalCurrencyString:[manager localCurrencyStringForAxeAmount:1]]*2;
    
    UIViewController * viewControllerToShowAlert = self;
    if (self.presentedViewController && [self.presentedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController * presentedController = (UINavigationController*)self.presentedViewController;
        viewControllerToShowAlert = presentedController.topViewController;
    }
    
    // if user selected an amount equal to or below wallet balance, but the fee will bring the total above the
    // balance, offer to reduce the amount to available funds minus fee
    if (self.amount <= manager.wallet.balance + fuzz && self.amount > 0) {
        int64_t amount = [manager.wallet maxOutputAmountUsingInstantSend:tx.isInstant];
        
        if (amount > 0 && amount < self.amount) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"insufficient funds for axe network fee", nil)
                                         message:[NSString stringWithFormat:NSLocalizedString(@"reduce payment amount by\n%@ (%@)?", nil),
                                                  [manager stringForAxeAmount:self.amount - amount],
                                                  [manager localCurrencyStringForAxeAmount:self.amount - amount]]
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* cancelButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"cancel", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                               [self cancelOrChangeAmount];
                                           }];
            UIAlertAction* reduceButton = [UIAlertAction
                                           actionWithTitle:[NSString stringWithFormat:@"%@ (%@)",
                                                            [manager stringForAxeAmount:amount - self.amount],
                                                            [manager localCurrencyStringForAxeAmount:amount - self.amount]]
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * action) {
                                               [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                           }];
            
            
            [alert addAction:cancelButton];
            [alert addAction:reduceButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            self.amount = amount;
        }
        else {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"insufficient funds for axe network fee", nil)
                                         message:nil
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                           
                                       }];
            
            
            [alert addAction:okButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
        }
    }
    else {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:NSLocalizedString(@"insufficient funds", nil)
                                     message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okButton = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"ok", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       
                                   }];
        [alert addAction:okButton];
        [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
    }
}

- (void)confirmTransaction:(BRTransaction *)tx toAddress:(NSString*)address withPrompt:(NSString *)prompt forAmount:(uint64_t)amount localCurrency:(NSString *)localCurrency localCurrencyAmount:(NSString *)localCurrencyAmount
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    __block BOOL previouslyWasAuthenticated = manager.didAuthenticate;
    UIViewController * viewControllerToShowAlert = self;
    if (self.presentedViewController && [self.presentedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController * presentedController = (UINavigationController*)self.presentedViewController;
        viewControllerToShowAlert = presentedController.topViewController;
    }
    
    if (! tx) { // tx is nil if there were insufficient wallet funds
        if (manager.didAuthenticate) {
            [self insufficientFundsForTransaction:tx forAmount:amount localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
        } else {
            [manager seedWithPrompt:prompt forAmount:amount completion:^(NSData * _Nullable seed) {
                if (seed) {
                    [self insufficientFundsForTransaction:tx forAmount:amount localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                } else {
                    [self cancelOrChangeAmount];
                }
                if (!previouslyWasAuthenticated) manager.didAuthenticate = NO;
            }];
        }
    } else {
        
        [manager.wallet signTransaction:tx withPrompt:prompt completion:^(BOOL signedTransaction) {
            if (!signedTransaction) {
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                             message:NSLocalizedString(@"error signing axe transaction", nil)
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                               
                                           }];
                [alert addAction:okButton];
                [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
            } else {
                
                if (! previouslyWasAuthenticated) manager.didAuthenticate = NO;
                
                if (! tx.isSigned) { // double check
                    [self cancelOrChangeAmount];
                    return;
                }
                if (self.navigationController.presentedViewController && [self.navigationController.presentedViewController isKindOfClass:[UINavigationController class]] && ((UINavigationController*)self.navigationController.presentedViewController).topViewController && [((UINavigationController*)self.navigationController.presentedViewController).topViewController isKindOfClass:[BRAmountViewController class]]) {
                    [self.navigationController.presentedViewController dismissViewControllerAnimated:TRUE completion:^{
                        
                    }];
                }

                __block BOOL waiting = YES, sent = NO;
                
                [(id)self.parentViewController.parentViewController startActivityWithTimeout:30.0];
                
                [[BRPeerManager sharedInstance] publishTransaction:tx completion:^(NSError *error) {
                    if (error) {
                        if (! waiting && ! sent) {
                            UIAlertController * alert = [UIAlertController
                                                         alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                                         message:error.localizedDescription
                                                         preferredStyle:UIAlertControllerStyleAlert];
                            UIAlertAction* okButton = [UIAlertAction
                                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                                       style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                       }];
                            [alert addAction:okButton];
                            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
                            [(id)self.parentViewController.parentViewController stopActivityWithSuccess:NO];
                            [self cancel:nil];
                        }
                    }
                    else if (! sent) { //TODO: show full screen sent dialog with tx info, "you sent b10,000 to bob"
                        if (tx.associatedShapeshift) {
                            [self startObservingShapeshift:tx.associatedShapeshift];
                            
                        }
                        sent = YES;
                        tx.timestamp = [NSDate timeIntervalSinceReferenceDate];
                        [manager.wallet registerTransaction:tx];
                        [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
                                                                    center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                               popOutAfterDelay:2.0]];
                        [(id)self.parentViewController.parentViewController stopActivityWithSuccess:YES];
                        [(id)self.parentViewController.parentViewController ping];
                        
                        
                        if (self.request.callbackScheme) {
                            NSURL * callback = [NSURL URLWithString:[self.request.callbackScheme
                                                                     stringByAppendingFormat:@"://callback=payack&address=%@&txid=%@",address,
                                                                     [NSString hexWithData:[NSData dataWithBytes:tx.txHash.u8
                                                                                                          length:sizeof(UInt256)].reverse]]];
                            [[UIApplication sharedApplication] openURL:callback options:@{} completionHandler:^(BOOL success) {
                                
                            }];
                        }
                        
                        [self reset:nil];
                    }
                    
                    waiting = NO;
                }];
                
                if (self.request.details.paymentURL.length > 0) {
                    uint64_t refundAmount = 0;
                    NSMutableData *refundScript = [NSMutableData data];
                    
                    [refundScript appendScriptPubKeyForAddress:manager.wallet.receiveAddress];
                    
                    for (NSNumber *amt in self.request.details.outputAmounts) {
                        refundAmount += amt.unsignedLongLongValue;
                    }
                    
                    // TODO: keep track of commonName/memo to associate them with outputScripts
                    BRPaymentProtocolPayment *payment =
                    [[BRPaymentProtocolPayment alloc] initWithMerchantData:self.request.details.merchantData
                                                              transactions:@[tx] refundToAmounts:@[@(refundAmount)] refundToScripts:@[refundScript] memo:nil];
                    
                    NSLog(@"posting payment to: %@", self.request.details.paymentURL);
                    
                    [BRPaymentRequest postPayment:payment scheme:@"axe" to:self.request.details.paymentURL timeout:20.0
                                       completion:^(BRPaymentProtocolACK *ack, NSError *error) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               [(id)self.parentViewController.parentViewController stopActivityWithSuccess:(! error)];
                                               
                                               if (error) {
                                                   if (! waiting && ! sent) {
                                                       UIAlertController * alert = [UIAlertController
                                                                                    alertControllerWithTitle:@""
                                                                                    message:error.localizedDescription
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                                                       UIAlertAction* okButton = [UIAlertAction
                                                                                  actionWithTitle:NSLocalizedString(@"ok", nil)
                                                                                  style:UIAlertActionStyleCancel
                                                                                  handler:^(UIAlertAction * action) {
                                                                                      
                                                                                  }];
                                                       [alert addAction:okButton];
                                                       [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
                                                       [(id)self.parentViewController.parentViewController stopActivityWithSuccess:NO];
                                                       [self cancel:nil];
                                                   }
                                               }
                                               else if (! sent) {
                                                   sent = YES;
                                                   tx.timestamp = [NSDate timeIntervalSinceReferenceDate];
                                                   [manager.wallet registerTransaction:tx];
                                                   [self.view addSubview:[[[BRBubbleView
                                                                            viewWithText:(ack.memo.length > 0 ? ack.memo : NSLocalizedString(@"sent!", nil))
                                                                            center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                                                          popOutAfterDelay:(ack.memo.length > 0 ? 3.0 : 2.0)]];
                                                   [(id)self.parentViewController.parentViewController stopActivityWithSuccess:YES];
                                                   [(id)self.parentViewController.parentViewController ping];
                                                   if (self.request.callbackScheme) {
                                                       NSURL * callback = [NSURL URLWithString:[self.request.callbackScheme
                                                                                                stringByAppendingFormat:@"://callback=payack&address=%@&txid=%@",address,
                                                                                                [NSString hexWithData:[NSData dataWithBytes:tx.txHash.u8
                                                                                                                                     length:sizeof(UInt256)].reverse]]];
                                                       [[UIApplication sharedApplication] openURL:callback options:@{} completionHandler:^(BOOL success) {
                                                           
                                                       }];
                                                   }
                                                   
                                                   [self reset:nil];
                                               }
                                               
                                               waiting = NO;
                                           });
                                       }];
                }
                else waiting = NO;
            }
        }];
    }
}

- (void)confirmSweep:(NSString *)privKey
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    
    if (! [privKey isValidAxePrivateKey] && ! [privKey isValidAxeBIP38Key]) return;
    
    BRBubbleView *statusView = [BRBubbleView viewWithText:NSLocalizedString(@"checking private key balance...", nil)
                                                   center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];
    
    statusView.font = [UIFont systemFontOfSize:14.0];
    statusView.customView = [[UIActivityIndicatorView alloc]
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [(id)statusView.customView startAnimating];
    [self.view addSubview:[statusView popIn]];
    
    [manager sweepPrivateKey:privKey withFee:YES completion:^(BRTransaction *tx, uint64_t fee, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [statusView popOut];
            
            if (error) {
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:@""
                                             message:error.localizedDescription
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                           }];
                [alert addAction:okButton];
                [self presentViewController:alert animated:YES completion:nil];
                [self cancel:nil];
            }
            else if (tx) {
                uint64_t amount = fee;
                
                for (NSNumber *amt in tx.outputAmounts) amount += amt.unsignedLongLongValue;
                self.sweepTx = tx;
                
                NSString *alertFmt = NSLocalizedString(@"Send %@ (%@) from this private key into your wallet? "
                                                       "The axe network will receive a fee of %@ (%@).", nil);
                NSString *alertMsg = [NSString stringWithFormat:alertFmt, [manager stringForAxeAmount:amount],
                                      [manager localCurrencyStringForAxeAmount:amount], [manager stringForAxeAmount:fee],
                                      [manager localCurrencyStringForAxeAmount:fee]];
                
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:@""
                                             message:alertMsg
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* cancelButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"cancel", nil)
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction * action) {
                                                   [self cancelOrChangeAmount];
                                               }];
                UIAlertAction* amountButton = [UIAlertAction
                                               actionWithTitle:[NSString stringWithFormat:@"%@ (%@)", [manager stringForAxeAmount:amount],
                                                                [manager localCurrencyStringForAxeAmount:amount]]
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [(id)self.parentViewController.parentViewController startActivityWithTimeout:30];
                                                   
                                                   [[BRPeerManager sharedInstance] publishTransaction:self.sweepTx completion:^(NSError *error) {
                                                       [(id)self.parentViewController.parentViewController stopActivityWithSuccess:(! error)];
                                                       
                                                       if (error) {
                                                           UIAlertController * alert = [UIAlertController
                                                                                        alertControllerWithTitle:NSLocalizedString(@"couldn't sweep balance", nil)
                                                                                        message:error.localizedDescription
                                                                                        preferredStyle:UIAlertControllerStyleAlert];
                                                           
                                                           UIAlertAction* okButton = [UIAlertAction
                                                                                      actionWithTitle:NSLocalizedString(@"ok", nil)
                                                                                      style:UIAlertActionStyleCancel
                                                                                      handler:^(UIAlertAction * action) {
                                                                                      }];
                                                           [alert addAction:okButton];
                                                           [self presentViewController:alert animated:YES completion:nil];
                                                           [self cancel:nil];
                                                           return;
                                                       }
                                                       
                                                       [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"swept!", nil)
                                                                                                   center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)]
                                                                               popIn] popOutAfterDelay:2.0]];
                                                       [self reset:nil];
                                                   }];
                                                   
                                               }];
                [alert addAction:amountButton];
                [alert addAction:cancelButton];
                [self presentViewController:alert animated:YES completion:nil];
            }
            else [self cancel:nil];
        });
    }];
}

- (void)showBalance:(NSString *)address
{
    if (! [address isValidBitcoinAddress]) return;
    
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    BRBubbleView *statusView = [BRBubbleView viewWithText:NSLocalizedString(@"checking address balance...", nil)
                                                   center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];
    
    statusView.font = [UIFont systemFontOfSize:14.0];
    statusView.customView = [[UIActivityIndicatorView alloc]
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [(id)statusView.customView startAnimating];
    [self.view addSubview:[statusView popIn]];
    
    [manager utxosForAddresses:@[address]
                    completion:^(NSArray *utxos, NSArray *amounts, NSArray *scripts, NSError *error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [statusView popOut];
                            
                            if (error) {
                                UIAlertController * alert = [UIAlertController
                                                             alertControllerWithTitle:NSLocalizedString(@"couldn't check address balance", nil)
                                                             message:error.localizedDescription
                                                             preferredStyle:UIAlertControllerStyleAlert];
                                UIAlertAction* okButton = [UIAlertAction
                                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                                           style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction * action) {
                                                           }];
                                [alert addAction:okButton];
                                [self presentViewController:alert animated:YES completion:nil];
                            }
                            else {
                                uint64_t balance = 0;
                                
                                for (NSNumber *amt in amounts) balance += amt.unsignedLongLongValue;
                                
                                NSString *alertMsg = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nbalance: %@ (%@)", nil),
                                                      address, [manager stringForAxeAmount:balance],
                                                      [manager localCurrencyStringForAxeAmount:balance]];
                                
                                UIAlertController * alert = [UIAlertController
                                                             alertControllerWithTitle:@""
                                                             message:alertMsg
                                                             preferredStyle:UIAlertControllerStyleAlert];
                                UIAlertAction* okButton = [UIAlertAction
                                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                                           style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction * action) {
                                                           }];
                                [alert addAction:okButton];
                                [self presentViewController:alert animated:YES completion:nil];
                            }
                        });
                    }];
}

- (void)cancelOrChangeAmount
{
    if (self.canChangeAmount && self.request && self.amount == 0) {
        UIViewController * viewControllerToShowAlert = self;
        if (self.presentedViewController && [self.presentedViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController * presentedController = (UINavigationController*)self.presentedViewController;
            viewControllerToShowAlert = presentedController.topViewController;
        }
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:NSLocalizedString(@"change payment amount?", nil)
                                     message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* cancelButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"cancel",nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                           [self cancel:nil];
                                       }];
        UIAlertAction* changeButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"change",nil)
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction * action) {
                                           [self confirmProtocolRequest:self.request];
                                       }];
        [alert addAction:cancelButton];
        [alert addAction:changeButton];
        [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
        self.amount = UINT64_MAX;
    }
    else [self cancel:nil];
}

- (void)hideTips
{
    if (self.tipView.alpha > 0.5) [self.tipView popOut];
}

- (BOOL)nextTip
{
    if (self.tipView.alpha < 0.5) return [(id)self.parentViewController.parentViewController nextTip];
    
    BRBubbleView *tipView = self.tipView;
    
    self.tipView = nil;
    [tipView popOut];
    
    if ([tipView.text hasPrefix:SCAN_TIP]) {
        self.tipView = [BRBubbleView viewWithText:CLIPBOARD_TIP
                                         tipPoint:CGPointMake(self.clipboardButton.center.x, self.clipboardButton.center.y + 10.0)
                                     tipDirection:BRBubbleTipDirectionDown];
        self.tipView.backgroundColor = tipView.backgroundColor;
        self.tipView.font = tipView.font;
        self.tipView.userInteractionEnabled = NO;
        [self.view addSubview:[self.tipView popIn]];
    }
    else if (self.showTips && [tipView.text hasPrefix:CLIPBOARD_TIP]) {
        self.showTips = NO;
        [(id)self.parentViewController.parentViewController tip:self];
    }
    
    return YES;
}

- (void)updateClipboardText
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *str = [[UIPasteboard generalPasteboard].string
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *text = @"";
        UIImage *img = [UIPasteboard generalPasteboard].image;
        NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSet];
        NSCharacterSet *separators = [NSCharacterSet alphanumericCharacterSet].invertedSet;
        
        if (str) {
            [set addObject:str];
            [set addObjectsFromArray:[str componentsSeparatedByCharactersInSet:separators]];
        }
        
        if (img) {
            @synchronized ([CIContext class]) {
                CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@(YES)}];
                
                if (! context) context = [CIContext context];
                
                for (CIQRCodeFeature *qr in [[CIDetector detectorOfType:CIDetectorTypeQRCode context:context
                                                                options:nil] featuresInImage:[CIImage imageWithCGImage:img.CGImage]]) {
                    [set addObject:[qr.messageString
                                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                }
            }
        }
        
        for (NSString *s in set) {
            BRPaymentRequest *req = [BRPaymentRequest requestWithString:s];
            
            if ([req.paymentAddress isValidBitcoinAddress]) {
                text = (req.label.length > 0) ? sanitizeString(req.label) : req.paymentAddress;
                break;
            }
            else if ([s hasPrefix:@"bitcoin:"]) {
                text = sanitizeString(s);
                break;
            }
        }
    });
}

- (void)payFirstFromArray:(NSArray *)array errorMessage:(NSString*)errorMessage
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSUInteger i = 0;
    
    for (NSString *str in array) {
        BRPaymentRequest *req = [BRPaymentRequest requestWithString:str];
        NSData *data = str.hexToData.reverse;
        
        i++;
        
        // if the clipboard contains a known txHash, we know it's not a hex encoded private key
        if (data.length == sizeof(UInt256) && [manager.wallet transactionForHash:*(UInt256 *)data.bytes]) continue;
        
        if ([req.paymentAddress isValidBitcoinAddress] || [req.paymentAddress isValidAxeAddress] || [str isValidBitcoinPrivateKey] || [str isValidAxePrivateKey] || [str isValidBitcoinBIP38Key] || [str isValidAxeBIP38Key] ||
            (req.r.length > 0 && ([req.scheme isEqual:@"bitcoin:"] || [req.scheme isEqual:@"axe:"]))) {
            [self performSelector:@selector(confirmRequest:) withObject:req afterDelay:0.1];// delayed to show highlight
            return;
        }
        else if (req.r.length > 0) { // may be BIP73 url: https://github.com/bitcoin/bips/blob/master/bip-0073.mediawiki
            [BRPaymentRequest fetch:req.r scheme:req.scheme timeout:5.0 completion:^(BRPaymentProtocolRequest *req, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) { // don't try any more BIP73 urls
                        [self payFirstFromArray:[array objectsAtIndexes:[array
                                                                         indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                                                                             return (idx >= i && ([obj hasPrefix:@"axe:"] || ! [NSURL URLWithString:obj]));
                                                                         }]] errorMessage:errorMessage];
                    }
                    else [self confirmProtocolRequest:req];
                });
            }];
            
            return;
        }
    }
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@""
                                 message:errorMessage
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"ok", nil)
                               style:UIAlertActionStyleCancel
                               handler:^(UIAlertAction * action) {
                               }];
    [alert addAction:okButton];
    [self presentViewController:alert animated:YES completion:nil];
    [self performSelector:@selector(cancel:) withObject:self afterDelay:0.1];
}

-(UILabel*)titleLabel {
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    UILabel * titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 100)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [titleLabel setBackgroundColor:[UIColor clearColor]];
    NSMutableAttributedString * attributedAxeString = [[manager attributedStringForAxeAmount:manager.wallet.balance withTintColor:[UIColor whiteColor]] mutableCopy];
    NSString * titleString = [NSString stringWithFormat:@" (%@)",
                              [manager localCurrencyStringForAxeAmount:manager.wallet.balance]];
    [attributedAxeString appendAttributedString:[[NSAttributedString alloc] initWithString:titleString attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}]];
    titleLabel.attributedText = attributedAxeString;
    return titleLabel;
}

-(void)updateTitleView {
    if (self.navigationItem.titleView && [self.navigationItem.titleView isKindOfClass:[UILabel class]]) {
        BRWalletManager *manager = [BRWalletManager sharedInstance];
        NSMutableAttributedString * attributedAxeString = [[manager attributedStringForAxeAmount:manager.wallet.balance withTintColor:[UIColor whiteColor]] mutableCopy];
        NSString * titleString = [NSString stringWithFormat:@" (%@)",
                                  [manager localCurrencyStringForAxeAmount:manager.wallet.balance]];
        [attributedAxeString appendAttributedString:[[NSAttributedString alloc] initWithString:titleString attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}]];
        ((UILabel*)self.navigationItem.titleView).attributedText = attributedAxeString;
        [((UILabel*)self.navigationItem.titleView) sizeToFit];
    } else {
        self.navigationItem.titleView = [self titleLabel];
    }
}

#pragma mark - Shapeshift

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    DSShapeshiftEntity * shapeshift = (DSShapeshiftEntity *)object;
    switch ([shapeshift.shapeshiftStatus integerValue]) {
        case eShapeshiftAddressStatus_Complete:
        {
            NSArray * shapeshiftsInProgress = [DSShapeshiftEntity shapeshiftsInProgress];
            if (![shapeshiftsInProgress count]) {
                self.shapeshiftLabel.text = shapeshift.shapeshiftStatusString;
                self.shapeshiftView.hidden = TRUE;
            }
            [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"shapeshift succeeded", nil)
                                                        center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                   popOutAfterDelay:2.0]];
            break;
        }
        case eShapeshiftAddressStatus_Received:
            self.shapeshiftLabel.text = shapeshift.shapeshiftStatusString;
        default:
            break;
    }
}


-(void)startObservingShapeshift:(DSShapeshiftEntity*)shapeshift {
    
    [shapeshift addObserver:self forKeyPath:@"shapeshiftStatus" options:NSKeyValueObservingOptionNew context:nil];
    [shapeshift routinelyCheckStatusAtInterval:10];
    self.shapeshiftView.hidden = FALSE;
}


// MARK: - IBAction

- (IBAction)tip:(id)sender
{
    if ([self nextTip]) return;
    
    if (! [sender isKindOfClass:[UIGestureRecognizer class]] || ! [[sender view] isKindOfClass:[UILabel class]]) {
        if (! [sender isKindOfClass:[UIViewController class]]) return;
        self.showTips = YES;
    }
    
    self.tipView = [BRBubbleView viewWithText:SCAN_TIP
                                     tipPoint:CGPointMake(self.scanButton.center.x, self.scanButton.center.y - 10.0)
                                 tipDirection:BRBubbleTipDirectionDown];
    self.tipView.font = [UIFont systemFontOfSize:14.0];
    [self.view addSubview:[self.tipView popIn]];
}

- (IBAction)enableInstantX:(id)sender {
    self.sendInstantly = ((UISwitch*)sender).isOn;
    [[NSUserDefaults standardUserDefaults] setBool:self.sendInstantly forKey:SEND_INSTANTLY_KEY];
}

- (IBAction)scanQR:(id)sender
{
    if ([self nextTip]) return;
    [BREventManager saveEvent:@"send:scan_qr"];
    if (! [sender isEqual:self.scanButton]) self.showBalance = YES;
    [sender setEnabled:NO];
    
    BRQRScanViewController *qrScanViewController = [[BRQRScanViewController alloc] init];
    qrScanViewController.viewModel.delegate = self;
    [self presentViewController:qrScanViewController animated:YES completion:nil];
}

- (IBAction)payToClipboard:(id)sender
{
    if ([self nextTip]) return;
    [BREventManager saveEvent:@"send:pay_clipboard"];
    
    NSString *str = [[UIPasteboard generalPasteboard].string
                     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    UIImage *img = [UIPasteboard generalPasteboard].image;
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSet];
    NSCharacterSet *separators = [NSCharacterSet alphanumericCharacterSet].invertedSet;
    
    if (str) {
        [set addObject:str];
        [set addObjectsFromArray:[str componentsSeparatedByCharactersInSet:separators]];
    }
    
    if (img) {
        @synchronized ([CIContext class]) {
            CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@(YES)}];
            
            if (! context) context = [CIContext context];
            
            for (CIQRCodeFeature *qr in [[CIDetector detectorOfType:CIDetectorTypeQRCode context:context options:nil]
                                         featuresInImage:[CIImage imageWithCGImage:img.CGImage]]) {
                [set addObject:[qr.messageString
                                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            }
        }
    }
    
    [sender setEnabled:NO];
    self.clearClipboard = YES;
    [self payFirstFromArray:set.array errorMessage:NSLocalizedString(@"clipboard doesn't contain a valid axe or bitcoin address", nil)];
}

- (IBAction)reset:(id)sender
{
    if (self.navigationController.topViewController != self.parentViewController.parentViewController) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    [BREventManager saveEvent:@"send:reset"];
    
    if (self.clearClipboard) [UIPasteboard generalPasteboard].string = @"";
    self.request = nil;
    self.shapeshiftRequest = nil;
    self.scheme = nil;
    self.associatedShapeshift = nil;
    [self cancel:sender];
    
}

- (IBAction)cancel:(id)sender
{
    [BREventManager saveEvent:@"send:cancel"];
    self.url = nil;
    self.sweepTx = nil;
    self.amount = 0;
    self.okAddress = self.okIdentity = nil;
    self.clearClipboard = self.useClipboard = NO;
    self.canChangeAmount = self.showBalance = NO;
    self.scanButton.enabled = self.clipboardButton.enabled = YES;
    [self updateClipboardText];
}

- (IBAction)startNFC:(id)sender NS_AVAILABLE_IOS(11.0) {
    [BREventManager saveEvent:@"send:nfc"];
    NFCNDEFReaderSession *session = [[NFCNDEFReaderSession alloc] initWithDelegate:self queue:dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT) invalidateAfterFirstRead:NO];
    session.alertMessage = NSLocalizedString(@"Please place your phone near NFC device.",nil);
    [session beginSession];
}

// MARK: - NFCNDEFReaderSessionDelegate

- (void)readerSession:(nonnull NFCNDEFReaderSession *)session didDetectNDEFs:(nonnull NSArray<NFCNDEFMessage *> *)messages NS_AVAILABLE_IOS(11.0) {
    NSMutableArray * array = [NSMutableArray array];
    for (NFCNDEFMessage *message in messages) {
        for (NFCNDEFPayload *payload in message.records) {
            NSLog(@"payload.payload %@",payload.payload);
            NSData * data = payload.payload;
            const unsigned char* bytes = [data bytes];
            
            if (bytes[0] == 0) {
                data = [data subdataWithRange:NSMakeRange(1, data.length - 1)];
            }
            NSLog(@"Payload data:%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            [array addObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self payFirstFromArray:array errorMessage:NSLocalizedString(@"NFC device didn't transmit a valid axe or bitcoin address", nil)];
    });
    [session invalidateSession];
}

// MARK: - BRAmountViewControllerDelegate

- (void)amountViewController:(BRAmountViewController *)amountViewController selectedAmount:(uint64_t)amount
{
    self.amount = amount;
    [self confirmProtocolRequest:self.request];
}


-(void)verifyShapeshiftAmountIsInBounds:(uint64_t)amount completionBlock:(void (^)(void))completionBlock failureBlock:(void (^)(void))failureBlock {
    UIViewController * viewControllerToShowAlert = self;
    if (self.presentedViewController && [self.presentedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController * presentedController = (UINavigationController*)self.presentedViewController;
        viewControllerToShowAlert = presentedController.topViewController;
    }
    [[DSShapeshiftManager sharedInstance] GET_marketInfo:^(NSDictionary *marketInfo, NSError *error) {
        if (error) {
            failureBlock();
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"shapeshift failed", nil)
                                         message:error.localizedDescription
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                       }];
            [alert addAction:okButton];
            [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
        } else {
            BRWalletManager *manager = [BRWalletManager sharedInstance];
            if ([DSShapeshiftManager sharedInstance].min > (amount * .97)) {
                failureBlock();
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"shapeshift failed", nil)
                                             message:[NSString stringWithFormat:NSLocalizedString(@"The amount you wanted to shapeshift is too low, "
                                                                                                  @"please input a value over %@", nil),[manager stringForAxeAmount:[DSShapeshiftManager sharedInstance].min / .97]]
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                           }];
                [alert addAction:okButton];
                [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
                return;
            } else if ([DSShapeshiftManager sharedInstance].limit < (amount * 1.03)) {
                failureBlock();
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"shapeshift failed", nil)
                                             message:[NSString stringWithFormat:NSLocalizedString(@"The amount you wanted to shapeshift is too high, "
                                                                                                  @"please input a value under %@", nil),[manager stringForAxeAmount:[DSShapeshiftManager sharedInstance].limit / 1.03]]
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                           }];
                [alert addAction:okButton];
                [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
                return;
            }
            completionBlock();
        }
    }];
    
}

- (void)amountViewController:(BRAmountViewController *)amountViewController shapeshiftBitcoinAmount:(uint64_t)amount approximateAxeAmount:(uint64_t)axeAmount
{
    UIViewController * viewControllerToShowAlert = self;
    if (self.presentedViewController && [self.presentedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController * presentedController = (UINavigationController*)self.presentedViewController;
        viewControllerToShowAlert = presentedController.topViewController;
    }
    MBProgressHUD *hud  = [MBProgressHUD showHUDAddedTo:self.navigationController.topViewController.view animated:YES];
    hud.label.text       = NSLocalizedString(@"Starting Shapeshift!", nil);
    
    [self verifyShapeshiftAmountIsInBounds:axeAmount completionBlock:^{
        //we know the exact amount of bitcoins we want to send
        BRWalletManager *m = [BRWalletManager sharedInstance];
        NSString * address = [NSString bitcoinAddressWithScriptPubKey:self.shapeshiftRequest.details.outputScripts.firstObject];
        NSString * returnAddress = m.wallet.receiveAddress;
        NSNumber * numberAmount = [m numberForAmount:amount];
        [[DSShapeshiftManager sharedInstance] POST_SendAmount:numberAmount withAddress:address returnAddress:returnAddress completionBlock:^(NSDictionary *shiftInfo, NSError *error) {
            [hud hideAnimated:TRUE];
            if (error) {
                NSLog(@"shapeshiftBitcoinAmount Error %@",error);
                
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"shapeshift failed", nil)
                                             message:error.localizedDescription
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                           }];
                [alert addAction:okButton];
                [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
                return;
            }
            NSString * depositAddress = shiftInfo[@"deposit"];
            NSString * withdrawalAddress = shiftInfo[@"withdrawal"];
            NSNumber * withdrawalAmount = shiftInfo[@"withdrawalAmount"];
            NSNumber * depositAmountNumber = @([shiftInfo[@"depositAmount"] doubleValue]);
            if (depositAmountNumber && [withdrawalAmount floatValue] && [depositAmountNumber floatValue]) {
                uint64_t depositAmount = [[[NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@",depositAmountNumber]] decimalNumberByMultiplyingByPowerOf10:8]
                                          unsignedLongLongValue];
                self.amount = depositAmount;
                
                DSShapeshiftEntity * shapeshift = [DSShapeshiftEntity registerShapeshiftWithInputAddress:depositAddress andWithdrawalAddress:withdrawalAddress withStatus:eShapeshiftAddressStatus_Unused fixedAmountOut:depositAmountNumber amountIn:depositAmountNumber];
                
                BRPaymentRequest * request = [BRPaymentRequest requestWithString:[NSString stringWithFormat:@"axe:%@?amount=%llu&label=%@&message=Shapeshift to %@",depositAddress,depositAmount,sanitizeString(self.shapeshiftRequest.commonName),withdrawalAddress]];
                [self confirmProtocolRequest:request.protocolRequest currency:@"axe" associatedShapeshift:shapeshift localCurrency:nil localCurrencyAmount:nil];
            }
        }];
    } failureBlock:^{
        [hud hideAnimated:TRUE];
    }];
}

- (void)amountViewController:(BRAmountViewController *)amountViewController shapeshiftAxeAmount:(uint64_t)amount
{
    UIViewController * viewControllerToShowAlert = self;
    if (self.presentedViewController && [self.presentedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController * presentedController = (UINavigationController*)self.presentedViewController;
        viewControllerToShowAlert = presentedController.topViewController;
    }
    MBProgressHUD *hud  = [MBProgressHUD showHUDAddedTo:self.navigationController.topViewController.view animated:YES];
    hud.label.text       = NSLocalizedString(@"Starting Shapeshift!", nil);
    [self verifyShapeshiftAmountIsInBounds:amount completionBlock:^{
        //we don't know the exact amount of bitcoins we want to send, we are just sending axe
        BRWalletManager *m = [BRWalletManager sharedInstance];
        NSString * address = [NSString bitcoinAddressWithScriptPubKey:self.shapeshiftRequest.details.outputScripts.firstObject];
        NSString * returnAddress = m.wallet.receiveAddress;
        self.amount = amount;
        DSShapeshiftEntity * shapeshift = [DSShapeshiftEntity unusedShapeshiftHavingWithdrawalAddress:address];
        NSString * depositAddress = shapeshift.inputAddress;
        
        if (shapeshift) {
            [hud hideAnimated:TRUE];
            BRPaymentRequest * request = [BRPaymentRequest requestWithString:[NSString stringWithFormat:@"axe:%@?amount=%llu&label=%@&message=Shapeshift to %@",depositAddress,self.amount,sanitizeString(self.request.commonName),address]];
            [self confirmProtocolRequest:request.protocolRequest currency:@"axe" associatedShapeshift:shapeshift localCurrency:nil localCurrencyAmount:nil];
        } else {
            [[DSShapeshiftManager sharedInstance] POST_ShiftWithAddress:address returnAddress:returnAddress completionBlock:^(NSDictionary *shiftInfo, NSError *error) {
                [hud hideAnimated:TRUE];
                if (error) {
                    NSLog(@"shapeshiftAxeAmount Error %@",error);
                    UIAlertController * alert = [UIAlertController
                                                 alertControllerWithTitle:NSLocalizedString(@"shapeshift failed", nil)
                                                 message:error.localizedDescription
                                                 preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction* okButton = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"ok", nil)
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction * action) {
                                               }];
                    [alert addAction:okButton];
                    [viewControllerToShowAlert presentViewController:alert animated:YES completion:nil];
                    return;
                }
                NSString * depositAddress = shiftInfo[@"deposit"];
                NSString * withdrawalAddress = shiftInfo[@"withdrawal"];
                if (withdrawalAddress && depositAddress) {
                    DSShapeshiftEntity * shapeshift = [DSShapeshiftEntity registerShapeshiftWithInputAddress:depositAddress andWithdrawalAddress:withdrawalAddress withStatus:eShapeshiftAddressStatus_Unused];
                    BRPaymentRequest * request = [BRPaymentRequest requestWithString:[NSString stringWithFormat:@"axe:%@?amount=%llu&label=%@&message=Shapeshift to %@",depositAddress,self.amount,sanitizeString(self.shapeshiftRequest.commonName),withdrawalAddress]];
                    [self confirmProtocolRequest:request.protocolRequest currency:@"axe" associatedShapeshift:shapeshift localCurrency:nil localCurrencyAmount:nil];
                }
            }];
        }
    } failureBlock:^{
        [hud hideAnimated:TRUE];
    }];
}

// MARK: - BRQRScanViewModelDelegate

- (void)qrScanViewModel:(BRQRScanViewModel *)viewModel didScanStandardNonPaymentRequest:(BRPaymentRequest *)request {
    [self dismissViewControllerAnimated:YES completion:^{
        if (request.amount > 0) self.canChangeAmount = YES;
        if (request.isValid && self.showBalance) {
            [self showBalance:request.paymentAddress];
            [self cancel:nil];
        }
        else {
            [self confirmRequest:request];
        }
    }];
}

- (void)qrScanViewModel:(BRQRScanViewModel *)viewModel
  didScanPaymentRequest:(BRPaymentRequest *)request
        protocolRequest:(BRPaymentProtocolRequest *)protocolRequest
                  error:(NSError *_Nullable)error {
    [self dismissViewControllerAnimated:YES completion:^{
        if (error) {
            request.r = nil;
        }
        
        if (error && !request.isValid) {
            UIAlertController *alert = [UIAlertController
                                        alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                        message:error.localizedDescription
                                        preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:nil];
            [alert addAction:okButton];
            [self presentViewController:alert animated:YES completion:nil];
            
            [BREventManager saveEvent:@"send:cancel"];
        }
        
        if (error) {
            [BREventManager saveEvent:@"send:unsuccessful_qr_payment_protocol_fetch"];
            [self confirmRequest:request]; // payment protocol fetch failed, so use standard request
        }
        else {
            [BREventManager saveEvent:@"send:successful_qr_payment_protocol_fetch"];
            [self confirmProtocolRequest:protocolRequest];
        }
    }];
}

- (void)qrScanViewModel:(BRQRScanViewModel *)viewModel didScanBIP73PaymentProtocolRequest:(BRPaymentProtocolRequest *)protocolRequest {
    [self dismissViewControllerAnimated:YES completion:^{
        [BREventManager saveEvent:@"send:successful_bip73"];
        [self confirmProtocolRequest:protocolRequest];
    }];
}

- (void)qrScanViewModelDidCancel:(BRQRScanViewModel *)viewModel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
