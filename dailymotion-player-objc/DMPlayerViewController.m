//  DailymotionPlayerController.m
//
//  Created by Olivier Poitrey on 26/09/11.
//  Copyright 2011 Dailymotion. All rights reserved.

#import "DMPlayerViewController.h"

static NSString *const DMAPIVersion = @"2.9.3";

@interface DMPlayerViewController () <UIAlertViewDelegate>

@property (nonatomic, readwrite) BOOL autoplay;
@property (nonatomic, readwrite) float bufferedTime;
@property (nonatomic, readwrite) float duration;
@property (nonatomic, readwrite) BOOL seeking;
@property (nonatomic, readwrite) BOOL paused;
@property (nonatomic, readwrite) BOOL ended;
@property (nonatomic, readwrite) BOOL started;
@property (nonatomic, readwrite) NSError *error;
@property (nonatomic, assign) BOOL inited;
@property (nonatomic, strong) NSDictionary *params;

#pragma mark Open In Safari
@property (nonatomic, strong) NSURL *safariURL;
- (void)openURLInSafari:(NSURL *)URL;

@end


@implementation DMPlayerViewController

- (void)dealloc {
  UIWebView *webView = (UIWebView *)self.view;
  webView.delegate = nil;
  [webView stopLoading];
}

- (void)setup {
  // See https://developer.dailymotion.com/player#player-parameters for available parameters
  _params = @{};

  _autoplay = [self.params[@"autoplay"] boolValue];
  _currentTime = 0;
  _bufferedTime = 0;
  _duration = NAN;
  _seeking = NO;
  _error = nil;
  _started = NO;
  _ended = NO;
  _muted = NO;
  _volume = 1;
  _paused = true;
  _fullscreen = NO;
  _webBaseURLString = @"http://www.dailymotion.com";
  _autoOpenExternalURLs = NO;
}

- (void)awakeFromNib {
  [super awakeFromNib];
  [self setup];
}

- (id)init {
    if (self = [super init]) {
      [self setup];
    }
    return self;
}

- (id)initWithParams:(NSDictionary *)params {
    if (self = [self init]) {
        _params = params;
    }
    return self;
}

- (id)initWithVideo:(NSString *)video params:(NSDictionary *)params {
    if (self = [self initWithParams:params]) {
        [self load:video];
    }
    return self;
}

- (id)initWithVideo:(NSString *)aVideo {
    return [self initWithVideo:aVideo params:nil];
}

- (void)initPlayerWithVideo:(NSString *)video {
    if (self.inited) return;
    self.inited = YES;

    UIWebView *webview = [[UIWebView alloc] init];
    webview.delegate = self;

    // Remote white default background
    webview.opaque = NO;
    webview.backgroundColor = [UIColor clearColor];

    // Allows autoplay (iOS 4+)
    if ([webview respondsToSelector:@selector(setMediaPlaybackRequiresUserAction:)]) {
        webview.mediaPlaybackRequiresUserAction = NO;
    }

    if ([webview respondsToSelector:@selector(setAllowsInlineMediaPlayback:)]) {
        webview.allowsInlineMediaPlayback = YES;
    }

    if ([self.params[@"fullscreen-state"] isEqualToString:@"fullscreen"]) {
        _fullscreen = YES;
    }

    // Autoresize by default
    webview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;


    // Hack: prevent vertical bouncing
    for (id subview in webview.subviews) {
        if ([[subview class] isSubclassOfClass:[UIScrollView class]]) {
            ((UIScrollView *)subview).bounces = NO;
            ((UIScrollView *)subview).scrollEnabled = NO;
        }
    }

    NSMutableString *url = [NSMutableString stringWithFormat:@"%@/embed/video/%@?api=location&objc_sdk_version=%@", self.webBaseURLString, video, DMAPIVersion];
    for (NSString *param in [self.params keyEnumerator]) {
        id value = self.params[param];
        if ([value isKindOfClass:NSString.class]) {
            value = [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        [url appendFormat:@"&%@=%@", param, value];
    }

    NSString *appName = NSBundle.mainBundle.bundleIdentifier;
    [url appendFormat:@"&app=%@", [appName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    [webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];

    self.view = webview;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    BOOL isFrame = ![[[request URL] absoluteString] isEqualToString:[[request mainDocumentURL] absoluteString]];
  
    if (isFrame) return YES;
  
    if ([request.URL.scheme isEqualToString:@"dmevent"]) {
        NSString *eventName = nil;
        NSMutableDictionary *data = [NSMutableDictionary dictionary];

        // Use reverse order so that the first occurrence of a key replaces those subsequent.
        for (NSString *component in [[request.URL.query componentsSeparatedByString:@"&"] reverseObjectEnumerator]) {
            if ([component length] == 0) continue;
            NSUInteger pos = [component rangeOfString:@"="].location;
            if (pos == NSNotFound) pos = component.length - 1;
            NSString *key = [component substringToIndex:pos];
            NSString *val = [component substringFromIndex:pos + 1];

            val = [[val stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                    stringByReplacingOccurrencesOfString:@"+" withString:@" "];

            if ([key isEqualToString:@"event"]) {
                eventName = val;
            }
            else {
                // stringByReplacingPercentEscapesUsingEncoding may return nil on malformed UTF8 sequence
                if (!val) val = @"";

                data[key] = val;
            }
        }

        if (eventName.length) {
            if ([eventName isEqualToString:@"timeupdate"]) {
                [self willChangeValueForKey:@"currentTime"];
                _currentTime = [data[@"time"] floatValue];
                [self didChangeValueForKey:@"currentTime"];
            }
            else if ([eventName isEqualToString:@"progress"]) {
                self.bufferedTime = [data[@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"durationchange"]) {
                self.duration = [data[@"duration"] floatValue];
            }
            else if ([eventName isEqualToString:@"fullscreenchange"]) {
                [self willChangeValueForKey:@"fullscreen"];
                _fullscreen = [data[@"fullscreen"] boolValue];
                [self didChangeValueForKey:@"fullscreen"];
            }
            else if ([eventName isEqualToString:@"volumechange"]) {
                self.volume = [data[@"volume"] floatValue];
            }
            else if ([eventName isEqualToString:@"play"] || [eventName isEqualToString:@"playing"]) {
                self.paused = NO;
            }
            else if ([eventName isEqualToString:@"start"]) {
                self.started = YES;
            }
            else if ([eventName isEqualToString:@"end"]) {
                self.ended = YES;
            }
            else if ([eventName isEqualToString:@"end"] || [eventName isEqualToString:@"pause"]) {
                self.paused = YES;
            }
            else if ([eventName isEqualToString:@"seeking"]) {
                self.seeking = YES;
                _currentTime = [data[@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"seeked"]) {
                self.seeking = NO;
                _currentTime = [data[@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"error"]) {
                NSDictionary *userInfo =
                        @{
                                @"code" : @([data[@"code"] intValue]) ?: @0,
                                @"title" : data[@"title"] ?: @"",
                                @"message" : data[@"message"] ?: @"",
                                NSLocalizedDescriptionKey : data[@"message"] ?: @"",
                        };
                self.error = [NSError errorWithDomain:@"DailymotionPlayer"
                                                 code:[data[@"code"] integerValue]
                                             userInfo:userInfo];
            }

            if ([self.delegate respondsToSelector:@selector(dailymotionPlayer:didReceiveEvent:)]) {
                [self.delegate dailymotionPlayer:self didReceiveEvent:eventName];
            }
        }

        return NO;
    }
    else if ([request.URL.path hasPrefix:@"/embed/video/"]) {
        return YES;
    }
    else {
      [self openURLInSafari:request.URL];
      return NO;
    }
}

- (void)setFullscreen:(BOOL)newFullscreen {
    [self api:@"fullscreen" arg:newFullscreen ? @"1" : @"0"];
    _fullscreen = newFullscreen;
}

- (void)setCurrentTime:(float)newTime {
    [self api:@"seek" arg:[NSString stringWithFormat:@"%f", newTime]];
    _currentTime = newTime;
}

- (void)play {
    [self api:@"play"];
}

- (void)togglePlay {
    [self api:@"toggle-play"];
}

- (void)pause {
    [self api:@"pause"];
}

- (void)notifyFullscreenChange {
    [self api:@"notifyFullscreenChanged"];
}

- (void)load:(NSString *)aVideo {
    if (!aVideo) {
        NSLog(@"Called DMPlayerViewController load: with a nil video id");
        return;
    }
    if (self.inited) {
        [self api:@"load" arg:aVideo];
    }
    else {
        [self initPlayerWithVideo:aVideo];
    }
}

- (void)loadVideo:(NSString *)videoId withParams:(NSDictionary *)params {
  self.params = params;
  [self load:videoId];
}


- (void)api:(NSString *)method arg:(NSString *)arg {
    if (!self.inited) return;
    if (!method) return;

    NSString *warnMessage = [self APIReadyWarnMessageForMethod:method];
    if (!self.started && warnMessage) {
        NSLog(@"%@", warnMessage);
    }

    UIWebView *webview = (UIWebView *)self.view;
    NSString *jsMethod = [NSString stringWithFormat:@"\"%@\"", method];
    NSString *jsArg = arg ? [NSString stringWithFormat:@"\"%@\"", [arg stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]] : @"null";
    [webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"player.api(%@, %@)", jsMethod, jsArg]];
}

- (void)api:(NSString *)method {
    [self api:method arg:nil];
}

- (NSString *) APIReadyWarnMessageForMethod:(NSString *)method {

    NSString * param = @{
      @"play"         : @"autoplay",
      @"toggle-play"  : @"autoplay",
      @"seek"         : @"start",
      @"quality"      : @"quality",
      @"muted"        : @"muted",
      @"toggle-muted" : @"muted"
    }[method];

    if (param) {
        return [NSString stringWithFormat:@"Warning [DMPlayerViewController]: \n"
                    "\tCalling `%@` method right after `apiready` event is not recommended.\n"
                    "\tAre you sure you don\'t want to use the `%@` parameter instead?\n"
                    "\tFor more information, see: https://developer.dailymotion.com/player#player-parameters", method, param];
    }
    else {
        return nil;
    }
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Open In Safari
- (void)openURLInSafari:(NSURL *)URL {
  if (self.autoOpenExternalURLs) {
    [[UIApplication sharedApplication] openURL:URL];
  }
  else {
    self.safariURL = URL;
    NSString *safariAlertTitle = [NSString stringWithFormat:NSLocalizedString(@"You are about to leave %@", nil), [[NSBundle mainBundle] infoDictionary][@"CFBundleExecutable"]];
    NSString *safariAlertMessage = [NSString stringWithFormat:NSLocalizedString(@"Do you want to open %@ in Safari?", nil), URL.host];
    UIAlertView *safariAlertView = [[UIAlertView alloc] initWithTitle:safariAlertTitle
                                                              message:safariAlertMessage
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                    otherButtonTitles:NSLocalizedString(@"Open", nil), nil];
    [safariAlertView show];
  }
}

#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex != alertView.cancelButtonIndex) {
    [[UIApplication sharedApplication] openURL:self.safariURL];
  }
  self.safariURL = nil;
}


@end
