//
//  DailymotionPlayerController.m
//  iOS
//
//  Created by Olivier Poitrey on 26/09/11.
//  Copyright 2011 Dailymotion. All rights reserved.
//

#import "DMPlayerViewController.h"

@interface DMPlayerViewController ()
@property (nonatomic, readwrite) BOOL autoplay;
@property (nonatomic, readwrite) float bufferedTime;
@property (nonatomic, readwrite) float duration;
@property (nonatomic, readwrite) BOOL seeking;
@property (nonatomic, readwrite) BOOL paused;
@property (nonatomic, readwrite) BOOL ended;
@property (nonatomic, readwrite) NSError *error;
@end

@implementation DMPlayerViewController
{
    NSString *video;
    NSDictionary *params;
    BOOL _fullscreen;
    float _currentTime;
}

@synthesize webBaseURLString = _webBaseURLString;
@synthesize delegate = _delegate;
@synthesize autoplay = _autoplay;
@synthesize bufferedTime = _bufferedTime;
@synthesize duration = _duration;
@synthesize seeking = _seeking;
@synthesize paused = _paused;
@synthesize ended = _ended;
@synthesize error = _error;
@synthesize muted = _muted;
@dynamic fullscreen;
@dynamic currentTime;
@synthesize volume = _volume;

- (id)initWithVideo:(NSString *)aVideo params:(NSDictionary *)someParams
{
    if ((self = [super init]))
    {
        video = aVideo;
        params = someParams;

        self.autoplay = [[params objectForKey:@"autoplay"] boolValue] == YES;
        self.currentTime = 0;
        self.bufferedTime = 0;
        self.duration = NAN;
        self.seeking = false;
        self.error = nil;
        self.ended = false;
        self.muted = false;
        self.volume = 1;
        self.paused = true;
        self.fullscreen = false;
    }
    return self;
}

- (id)initWithVideo:(NSString *)aVideo
{
    return [self initWithVideo:aVideo params:nil];
}

- (void)loadView
{
    UIWebView *webview = [[UIWebView alloc] init];
    webview.delegate = self;

    // Remote white default background
    webview.opaque = NO;
    webview.backgroundColor = [UIColor clearColor];

    // Allows autoplay (iOS 4+)
    if ([webview respondsToSelector:@selector(setMediaPlaybackRequiresUserAction:)])
        webview.mediaPlaybackRequiresUserAction = NO;

    // Autoresize by default
    webview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;


    // Hack: prevent vertical bouncing
    for (id subview in webview.subviews)
    {
        if ([[subview class] isSubclassOfClass:[UIScrollView class]])
        {
            ((UIScrollView *)subview).bounces = NO;
            ((UIScrollView *)subview).scrollEnabled = NO;
        }
    }


    NSMutableString *url = [NSMutableString stringWithFormat:@"%@/embed/video/%@?api=location", self.webBaseURLString, video];
    for (NSString *param in [params keyEnumerator])
    {
        id value = [params objectForKey:param];
        if ([value isKindOfClass:NSString.class])
        {
            value = [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        [url appendFormat:@"&%@=%@", param, value];
    }
    [webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
                  
    self.view = webview;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.scheme isEqualToString:@"dmevent"])
    {
        NSString *eventName = nil;
        NSMutableDictionary *data = [NSMutableDictionary dictionary];

        // Use reverse order so that the first occurrence of a key replaces those subsequent.
        for (NSString *component in [[request.URL.query componentsSeparatedByString:@"&"] reverseObjectEnumerator])
        {
            if ([component length] == 0) continue;
            NSUInteger pos = [component rangeOfString:@"="].location;
            if (pos == NSNotFound) pos = component.length - 1;
            NSString *key = [component substringToIndex:pos];
            NSString *val = [component substringFromIndex:pos + 1];
            
            val = [[val stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                   stringByReplacingOccurrencesOfString:@"+" withString:@" "];

            if ([key isEqualToString:@"event"])
            {
                eventName = val;
            }
            else
            {
                // stringByReplacingPercentEscapesUsingEncoding may return nil on malformed UTF8 sequence
                if (!val) val = @"";

                [data setObject:val forKey:key];
            }
        }

        if (eventName || ![eventName isEqualToString:@""])
        {
            if ([eventName isEqualToString:@"timeupdate"])
            {
                self.currentTime = [[data objectForKey:@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"progress"])
            {
                self.bufferedTime = [[data objectForKey:@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"durationchange"])
            {
                self.duration = [[data objectForKey:@"duration"] floatValue];
            }
            else if ([eventName isEqualToString:@"fullscreenchange"])
            {
                self.fullscreen = [[data objectForKey:@"fullscreen"] boolValue];
            }
            else if ([eventName isEqualToString:@"volumechange"])
            {
                self.volume = [[data objectForKey:@"volume"] floatValue];
            }
            else if ([eventName isEqualToString:@"play"] || [eventName isEqualToString:@"playing"])
            {
                self.paused = NO;
            }
            else if ([eventName isEqualToString:@"ended"])
            {
                self.ended = YES;
            }
            else if ([eventName isEqualToString:@"ended"] || [eventName isEqualToString:@"pause"])
            {
                self.paused = YES;
            }
            else if ([eventName isEqualToString:@"seeking"])
            {
                self.seeking = YES;
                self.currentTime = [[data objectForKey:@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"seeked"])
            {
                self.seeking = NO;
                self.currentTime = [[data objectForKey:@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"error"])
            {
                self.error = [NSError errorWithDomain:@"DailymotionPlayer"
                                                 code:[[data objectForKey:@"code"] integerValue]
                                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [data objectForKey:@"code"], @"code",
                                                       [data objectForKey:@"title"], @"title",
                                                       [data objectForKey:@"message"], @"message",
                                                       [data objectForKey:@"message"], NSLocalizedDescriptionKey,
                                                       nil]];
            }

            if ([self.delegate respondsToSelector:@selector(dailymotionPlayer:didReceiveEvent:)])
            {
                [self.delegate dailymotionPlayer:self didReceiveEvent:eventName];
            }
        }

        return NO;
    }
    return YES;
}

- (BOOL)fullscreen
{
    return _fullscreen;
}
- (void)setFullscreen:(BOOL)newFullscreen
{
    [self api:@"fullscreen" arg:newFullscreen ? @"1" : @"0"];
    _fullscreen = newFullscreen;
}

- (float)currentTime
{
    return _currentTime;
}
- (void)setCurrentTime:(float)newTime
{
    [self api:@"seek" arg:[NSString stringWithFormat:@"%f", newTime]];
    _currentTime = newTime;
}

- (void)play
{
    [self api:@"play"];
}

- (void)togglePlay
{
    [self api:@"toggle-play"];
}

- (void)pause
{
    [self api:@"pause"];
}

- (void)load:(NSString *)aVideo
{
    [self api:@"load" arg:aVideo];
}


- (void)api:(NSString *)method arg:(NSString *)arg
{
    if (!method) return;
    UIWebView *webview = (UIWebView *)self.view;
    NSString *jsMethod = [NSString stringWithFormat:@"\"%@\"", method];
    NSString *jsArg = arg ? [NSString stringWithFormat:@"\"%@\"", [arg stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]] : @"null";    
    [webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"player.api(%@, %@)", jsMethod, jsArg]];
}

- (void)api:(NSString *)method
{
    [self api:method arg:nil];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}


@end
