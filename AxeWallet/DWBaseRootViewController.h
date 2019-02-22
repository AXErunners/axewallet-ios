//
//  DWBaseRootViewController.h
//  axewallet
//
//  Created by Andrew Podkovyrin on 21/11/2018.
//  Copyright © 2019 Axe Core. All rights reserved.
//

#import <KVO-MVVM/KVOUIViewController.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWBaseRootViewController : KVOUIViewController

- (void)protectedViewDidAppear NS_REQUIRES_SUPER;

- (void)forceUpdateWalletAuthentication:(BOOL)cancelled;

- (void)showNewWalletController;

@end

NS_ASSUME_NONNULL_END
