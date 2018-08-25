# AXEwallet

[![Build Status](https://travis-ci.com/AXErunners/axewallet-ios.svg?branch=master)](https://travis-ci.com/AXErunners/axewallet-ios)

<p align="center" >
<img src="AxeWallet/Images.xcassets/AppIcon.appiconset/icon_83.5@2x.png" alt="AXE wallet logo">
</p>

Axewallet (dashwallet fork) is a real standalone Axe client. There is no server to get hacked or go down, so you can always access your money.
Using [SPV](https://en.bitcoin.it/wiki/Thin_Client_Security#Header-Only_Clients) mode, Axewallet connects directly to the Axe network with the fast performance you need on a mobile device.

Axewallet is designed to protect you from malware, browser security holes, even physical theft. With AES hardware encryption, app sandboxing,
keychain and code signatures, Axewallet represents a significant security advantage over web and desktop wallets, and other mobile platforms.
Simplicity is Axewallet’s core design principle. A simple backup phrase is all you need to restore your wallet on another device if yours is ever lost or broken.
Because Axewallet is deterministic, your balance and transaction history can be recovered from just your backup phrase.

## Features:
- [“simplified payment verification”](https://github.com/AXErunners/axe/wiki/SPV) for fast mobile performance
- no server to get hacked or go down
- single backup phrase that works forever
- private keys never leave your device
- import password protected paper wallets
- "payment protocol” payee identity certification
- Shapeshift integration (Pay any BTC Address by just scanning the BTC QR Code)

## URL scheme:
Axewallet supports the [x-callback-url](http://x-callback-url.com/) specification with the following URLs:
```
axe://x-callback-url/address?x-success=myscheme://myaction
```
this will callback with the current wallet receive address: myscheme://myaction?address=1XXXX
the following will ask the user to authorize copying a list of their wallet addresses to the clipboard before calling back:
```
axe://x-callback-url/addresslist?x-success=myscheme://myaction
```

## WARNING:

installation on jailbroken devices is strongly discouraged

Any jailbreak app can grant itself access to every other app's keychain data
and rob you by self-signing as described [here](http://www.saurik.com/id/8)
and including `<key>application-identifier</key><string>*</string>` in its
.entitlements file.
