//
//  DailymotionPlayerController.m
//  iOS
//
//  Created by Olivier Poitrey on 26/09/11.
//  Copyright 2011 Dailymotion. All rights reserved.
//

#import "Dailymotion.h"
#import "DailymotionPlayerViewController.h"

@implementation DailymotionPlayerViewController
@synthesize delegate, autoplay, bufferedTime, duration, seeking, paused, ended, error;
@dynamic muted, fullscreen, currentTime, volume;

- (id)initWithVideo:(NSString *)aVideo params:(NSDictionary *)someParams
{
    if ((self = [super init]))
    {
        video = aVideo;
        params = someParams;

        autoplay = [[params objectForKey:@"autoplay"] boolValue] == YES;
        currentTime = 0;
        bufferedTime = 0;
        duration = NAN;
        seeking = false;
        error = nil;
        ended = false;
        muted = false;
        volume = 1;
        paused = true;
        fullscreen = false;
    }
    return self;
}

- (id)initWithVideo:(NSString *)aVideo
{
    return [self initWithVideo:aVideo params:nil];
}

- (void)loadView
{
    UIWebView *webview = [[[UIWebView alloc] init] autorelease];
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


    NSMutableString *url = [NSMutableString stringWithFormat:@"%@/embed/video/%@?api=location", Dailymotion.WebEndpoint, video];
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
                currentTime = [[data objectForKey:@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"progress"])
            {
                bufferedTime = [[data objectForKey:@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"durationchange"])
            {
                duration = [[data objectForKey:@"duration"] floatValue];
            }
            else if ([eventName isEqualToString:@"fullscreenchange"])
            {
                fullscreen = [[data objectForKey:@"fullscreen"] boolValue];
            }
            else if ([eventName isEqualToString:@"volumechange"])
            {
                volume = [[data objectForKey:@"volume"] floatValue];
            }
            else if ([eventName isEqualToString:@"play"] || [eventName isEqualToString:@"playing"])
            {
                paused = NO;
            }
            else if ([eventName isEqualToString:@"ended"])
            {
                ended = YES;
            }
            else if ([eventName isEqualToString:@"ended"] || [eventName isEqualToString:@"pause"])
            {
                paused = YES;
            }
            else if ([eventName isEqualToString:@"seeking"])
            {
                seeking = YES;
                currentTime = [[data objectForKey:@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"seeked"])
            {
                seeking = NO;
                currentTime = [[data objectForKey:@"time"] floatValue];
            }
            else if ([eventName isEqualToString:@"error"])
            {
                error = [NSError errorWithDomain:@"DailymotionPlayer"
                                            code:[[data objectForKey:@"code"] integerValue]
                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [data objectForKey:@"code"], @"code",
                                                  [data objectForKey:@"title"], @"title",
                                                  [data objectForKey:@"message"], @"message",
                                                  [data objectForKey:@"message"], NSLocalizedDescriptionKey,
                                                  nil]];
            }

            if ([delegate respondsToSelector:@selector(dailymotionPlayer:didReceiveEvent:)])
            {
                [delegate dailymotionPlayer:self didReceiveEvent:eventName];
            }
        }

        return NO;
    }
    return YES;
}

- (BOOL)fullscreen
{
    return fullscreen;
}
- (void)setFullscreen:(BOOL)newFullscreen
{
    [self api:@"fullscreen" arg:newFullscreen ? @"1" : @"0"];
    fullscreen = newFullscreen;
}

- (float)currentTime
{
    return currentTime;
}
- (void)setCurrentTime:(float)newTime
{
    [self api:@"seek" arg:[NSString stringWithFormat:@"%f", newTime]];
    currentTime = newTime;
}

- (BOOL)muted
{
    return muted;
}
- (void)setMuted:(BOOL)newMuted
{
    // TODO: handle locally
    muted = newMuted;
}

- (float)volume
{
    return volume;
}
- (void)setVolume:(float)newVolume
{
    // TODO: handle locally
    volume = newVolume;
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

- (void)dealloc
{
    [video release];
    [params release];
    [super dealloc];
}

@end
