//
//  DailymotionPlayerController.m
//  iOS
//
//  Created by Olivier Poitrey on 26/09/11.
//  Copyright 2011 Dailymotion. All rights reserved.
//

#import "DMPlayerViewController.h"
#import "DMAlert.h"

@interface DMPlayerViewController ()

@property (nonatomic, readwrite) BOOL autoplay;
@property (nonatomic, readwrite) float bufferedTime;
@property (nonatomic, readwrite) float duration;
@property (nonatomic, readwrite) BOOL seeking;
@property (nonatomic, readwrite) BOOL paused;
@property (nonatomic, readwrite) BOOL ended;
@property (nonatomic, readwrite) NSError *error;
@property (nonatomic, assign) BOOL inited;
@property (nonatomic, strong) NSDictionary *params;

@end


@implementation DMPlayerViewController

- (id)init {
    self = [super init];
    if (self) {
        _params = @{};

        _autoplay = [self.params[@"autoplay"] boolValue];
        _currentTime = 0;
        _bufferedTime = 0;
        _duration = NAN;
        _seeking = false;
        _error = nil;
        _ended = false;
        _muted = false;
        _volume = 1;
        _paused = true;
        _fullscreen = false;
        _webBaseURLString = @"http://www.dailymotion.com";
    }
    return self;
}

- (id)initWithParams:(NSDictionary *)params {
    self = [self init];
    if (self) {
        _params = params;
    }
    return self;
}

- (id)initWithVideo:(NSString *)video params:(NSDictionary *)params {
    self = [self initWithParams:params];
    if (self) {
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

    if ([webview respondsToSelector:@selector(setAllowsInlineMediaPlayback:)] && self.params[@"webkit-playsinline"]) {
        webview.allowsInlineMediaPlayback = YES;
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

    NSMutableString *url = [NSMutableString stringWithFormat:@"%@/embed/video/%@?api=location", self.webBaseURLString, video];
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
            else if ([eventName isEqualToString:@"ended"]) {
                self.ended = YES;
            }
            else if ([eventName isEqualToString:@"ended"] || [eventName isEqualToString:@"pause"]) {
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
        [DMAlertView showAlertViewWithTitle:[NSString stringWithFormat:NSLocalizedString(@"You are about to leave %@", nil),
                                                                       [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"]]
                                    message:[NSString stringWithFormat:NSLocalizedString(@"Do you want to open %@ in Safari?", nil),
                                                                       request.URL.host]
                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                          otherButtonTitles:@[NSLocalizedString(@"Open", nil)]
                               dismissBlock:^(NSInteger buttonIndex) {
                                   [[UIApplication sharedApplication] openURL:request.URL];
                               }
                                cancelBlock:nil];
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


- (void)api:(NSString *)method arg:(NSString *)arg {
    if (!self.inited) return;
    if (!method) return;
    UIWebView *webview = (UIWebView *)self.view;
    NSString *jsMethod = [NSString stringWithFormat:@"\"%@\"", method];
    NSString *jsArg = arg ? [NSString stringWithFormat:@"\"%@\"", [arg stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]] : @"null";
    [webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"player.api(%@, %@)", jsMethod, jsArg]];
}

- (void)api:(NSString *)method {
    [self api:method arg:nil];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


@end
