#Dailymotion Player SDK for iOS

This repository contains the official open source Objective-C SDK that allows you to embed Dailymotion Videos in your iOS application.

See documentation at [http://www.dailymotion.com/doc/api/sdk-objc.html](http://www.dailymotion.com/doc/api/sdk-objc.html).

For a full documentation of the Player API, see [https://developer.dailymotion.com/player](https://developer.dailymotion.com/player#player-parameters)

##Installation

###CocoaPods

Just add the following line to your `Podfile` (See [CocoaPods.org](http://www.cocoapods.org) for more information)

```
pod 'dailymotion-player-objc'
```

###Manually

Just drag and drop the `dailymotion-player-objc` folder into your project.

##Usage

Check out the repository and open `dailymotion-sdk-objc.xcodeproj` for a working example of how to embed the Dailymotion Player into your app.

Also look at the `init` methods of `DMPlayerViewController` for ways to embed the Dailymotion Player without using storyboards.

###About App Transport Security (iOS 9+)

Starting with iOS9, Apple added a new [App Transport Security](https://developer.apple.com/library/prerelease/ios/technotes/App-Transport-Security-Technote/index.html) policy.
As Dailymotion player uses an `UIWebView` to embed his video player, you'll need to define a few ATS exceptions in your `Info.plist` for the video player to work properly.

#### Option 1: Disabling ATS

If your application already rely on several non-https services, or if you allow your users to load arbitrary web sites, you might want to completely disable ATS.
You can do it by adding the following to your app's `Info.plist` :

``` xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

#### Option 2: White-listing dailymotion.com

If you cannot afford to disable ATS, you'll probably want to add `dailymotion.com` to the ATS exception list instead.
You can do it by adding the following to your app's `Info.plist` :

``` xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>dailymotion.com</key>
    <dict>
      <key>NSIncludesSubdomains</key>
      <true/>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <true/>
    </dict>
  </dict>
</dict>
```

###Feedback

We are relying on the [GitHub issues tracker](issues) for feedback. File bugs or other issues http://github.com/dailymotion/dailymotion-sdk-objc/issues

###TODO List

Here is what is coming in the next months:

- Player SDK for Mac OS X
- New API SDK for iOS and Mac OS X

###Need the API SDK?

NOTE: This is version 2.9.0 and higher of the Dailymotion SDK. This version no longer supports the API SDK.

Check out released tag 2.0.2 for the latest API SDK version: https://github.com/dailymotion/dailymotion-sdk-objc/releases/tag/2.0.2.

If you need iOS 3+ support, please check out https://github.com/dailymotion/dailymotion-sdk-objc/tree/1.8.

**Warning:** **This library is up-to-date and maintained if you want to use the Dailymotion Player on your native iOS apps**. However, the API SDK is not maintained anymore and will be totally replaced in the coming future. Be sure to check this page again to know when the new version of the API SDK will be available.
