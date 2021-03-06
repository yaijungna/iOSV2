//
//  TpWebView.m
//
//  Created by Yoav Yaari.
//  Copyright (c) 2013 Yoav Yaari. All rights reserved.
//

#import "TpWebView.h"
#import "TpUrlManager.h"
#import "TpWebNavigationBar.h"
#import "BaseTrialpayManager.h"
#import "TpArcSupport.h"
#import "TpSdkConstants.h"

@interface TpWebView() {
    CGAffineTransform prevTransform;
}

@property (strong) NSString *initialUrl;
@property (strong) UIWebView *webViewContainer;
@property (strong) UIBarButtonItem *flexibleSpaceArea;
@property (strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, copy) NSString *currentTouchpointName;
@property (nonatomic, strong) NSURLRequest *currentRequest;

// Set up to use it for opening external apps. URL to a target is passed, use its scheme to define the app type.
@property (nonatomic, copy) void(^externalAppOpener)(NSURL *);

@end

@implementation TpWebView {
    CGFloat popupHorizontalMargin;
    CGFloat popupVerticalMargin;
    
    CGSize offerwallContainerSizeDelta;
}

/*
 * Loads the offerwall using the given frame size.
 * This is currently being overriden by -buildViewWithNavigationBarAndWidth:height:
 */
- (id)initWithFrame:(CGRect)frame {
    TPLogEnter;
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizesSubviews = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.initialUrl = nil;

        popupHorizontalMargin = kTpPopupHorizontalMargin;
        popupVerticalMargin   = kTpPopupVerticalMargin;

        offerwallContainerSizeDelta = CGSizeMake(0, 0);
    }
    return self;
}

- (void)dealloc {
    // break self referencing cycle so that ARC can claim memory
    TP_ARC_RELEASE(delegate);
    // stop delegates and webviews, if needed
    [self stopWebViews];

    // help ARC claim the memory faster
    TP_ARC_RELEASE(offerContainer);
    TP_ARC_RELEASE(offerwallContainer);
    TP_ARC_RELEASE(webViewContainer);
    TP_ARC_RELEASE(mainView);
    TP_ARC_RELEASE(navigationBar);

    TP_ARC_RELEASE(webNavigationBar);
    TP_ARC_RELEASE(backButton);
    TP_ARC_RELEASE(flexibleSpaceArea);
    TP_ARC_RELEASE(doneButton);
    TP_ARC_RELEASE(loadingIndicator);
    TP_ARC_RELEASE(initialUrl);

    [super TP_DEALLOC];
}

/*
 * Sets the given offerwallUrl as the initialUrl for the offerwallContainer.
 * The url is loaded in -layoutSubviews
 */
- (void)loadRequest:(NSString *)urlString {
    TPLogEnter;
    
    if ([urlString rangeOfString:@"tp_base_page=1"].location == NSNotFound)
        [self setInitialUrl:[NSString stringWithFormat:@"%@&tp_base_page=1", urlString]];
    else
        [self setInitialUrl:urlString];
    
    if (nil != self.offerwallContainer) {
        NSURL *url = [NSURL URLWithString:self.initialUrl];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.offerwallContainer loadRequest:request];
    }
}

#pragma mark - pragmatically build views

- (UIView *)buildWebNavigationBarWithWidth:(CGFloat)width height:(CGFloat)height {
    CGRect frame = CGRectMake(0.0, 0.0, width, height);
    self.webNavigationBar = [[[TpWebNavigationBar alloc] initWithFrame:frame touchpointName:self.currentTouchpointName] TP_AUTORELEASE];

    self.webNavigationBar.autoresizesSubviews = YES;
    self.webNavigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.webNavigationBar.clearsContextBeforeDrawing = NO;
    self.webNavigationBar.contentMode = UIViewContentModeScaleToFill;
    self.webNavigationBar.multipleTouchEnabled = NO;
    self.webNavigationBar.userInteractionEnabled = YES;

    self.webNavigationBar.tpDelegate = self;
    self.webNavigationBar.hidden = YES;
    return self.webNavigationBar;
}

/*
 * Setting up the view structure with code.
 * We do not use XIBs in order to reduce plugin integration complexity
 */
- (UIView *)buildNavigationBarWithWidth:(CGFloat)width height:(CGFloat)height {
    TPLog(@"buildViewWithWidth:%f height:%f", width, height);
    
    float navBarHeight = 44.0;
    
    // Build navigationBar
    self.navigationBar = [[[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, width, navBarHeight)] TP_AUTORELEASE];
    self.navigationBar.alpha = 1.000;
    self.navigationBar.autoresizesSubviews = YES;
    self.navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    self.navigationBar.barStyle = UIBarStyleDefault;
    self.navigationBar.clearsContextBeforeDrawing = NO;
    self.navigationBar.clipsToBounds = NO;
    self.navigationBar.contentMode = UIViewContentModeScaleToFill;
    self.navigationBar.frame = CGRectMake(0.0, 0.0, width, 44.0);
    self.navigationBar.hidden = NO;
    self.navigationBar.multipleTouchEnabled = NO;
    self.navigationBar.opaque = NO;
    self.navigationBar.tag = 0;
    self.navigationBar.userInteractionEnabled = YES;
    
    self.backButton = [[[UIBarButtonItem alloc] init] TP_AUTORELEASE];
    self.backButton.imageInsets = UIEdgeInsetsZero;
    self.backButton.style = UIBarButtonItemStyleBordered;
    self.backButton.tag = 0;
    self.backButton.title = @"Back";
    self.backButton.width = 0.000;
    self.backButton.action = @selector(backButtonPushed:);
    
    self.flexibleSpaceArea = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] TP_AUTORELEASE];
    self.flexibleSpaceArea.enabled = YES;
    self.flexibleSpaceArea.imageInsets = UIEdgeInsetsZero;
    self.flexibleSpaceArea.style = UIBarButtonItemStylePlain;
    self.flexibleSpaceArea.tag = 0;
    self.flexibleSpaceArea.width = 0.000;
    
    self.doneButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:nil action:nil] TP_AUTORELEASE];
    self.doneButton.enabled = YES;
    self.doneButton.imageInsets = UIEdgeInsetsZero;
    self.doneButton.style = UIBarButtonItemStyleBordered;
    self.doneButton.tag = 0;
    self.doneButton.width = 0.000;
    self.doneButton.action = @selector(doneButtonPushed:);
    return self.navigationBar;
}

- (UIView *)buildViewWithNavigationBarAndWidth:(CGFloat)width height:(CGFloat)height {
    // Build offerwallContainer
    float navBarHeight = 44.0;

    self.offerwallContainer = [[[UIWebView alloc] initWithFrame:CGRectMake(0.0, navBarHeight, width, height-navBarHeight)] TP_AUTORELEASE];
    
    self.offerwallContainer.alpha = 1.000;
    self.offerwallContainer.autoresizesSubviews = YES;
    self.offerwallContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.offerwallContainer.backgroundColor = [UIColor colorWithRed:1.000 green:1.000 blue:1.000 alpha:1.000];
    self.offerwallContainer.clearsContextBeforeDrawing = YES;
    self.offerwallContainer.clipsToBounds = NO;
    self.offerwallContainer.contentMode = UIViewContentModeScaleToFill;
    self.offerwallContainer.hidden = NO;
    self.offerwallContainer.multipleTouchEnabled = NO;
    self.offerwallContainer.opaque = YES;
    self.offerwallContainer.scalesPageToFit = NO;
    self.offerwallContainer.tag = 0;
    self.offerwallContainer.userInteractionEnabled = YES;
    self.offerwallContainer.delegate = self;
    
    [[self.offerwallContainer scrollView] setBounces:YES];
    [self.offerwallContainer setAllowsInlineMediaPlayback:YES];
    [self.offerwallContainer setMediaPlaybackRequiresUserAction:NO];
    [self.offerwallContainer setScalesPageToFit:YES];
    
    // Build main view (container)
    self.mainView = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)] TP_AUTORELEASE];
    self.mainView.alpha = 1.000;
    self.mainView.autoresizesSubviews = YES;
    self.mainView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mainView.backgroundColor = [UIColor colorWithWhite:1.000 alpha:1.000];
    self.mainView.clearsContextBeforeDrawing = YES;
    self.mainView.clipsToBounds = NO;
    self.mainView.contentMode = UIViewContentModeScaleToFill;
    self.mainView.hidden = NO;
    self.mainView.multipleTouchEnabled = NO;
    self.mainView.opaque = YES;
    self.mainView.tag = 0;
    self.mainView.userInteractionEnabled = YES;

    [self.mainView addSubview:[self buildWebNavigationBarWithWidth:width height:navBarHeight]];
    [self.mainView addSubview:[self buildNavigationBarWithWidth:width height:navBarHeight]];

    [self setupNavigationBarUsingBack:NO];
    [self.mainView addSubview:self.offerwallContainer];
    
    return self.mainView;
}

/*
 * Returns the "name" of the UIWebView element for logging purposes
 */
- (NSString *)getWebViewName:(UIWebView *)webView {
    return [webView isEqual:self.offerwallContainer] ? kTPOfferwallContainer : kTPOfferContainer;
}

#pragma mark - Popup mode
- (void)setupAsPopup {
    // setup content view (has webviews): shadow, corners,
    self.mainView.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleLeftMargin |
            UIViewAutoresizingFlexibleBottomMargin |
            UIViewAutoresizingFlexibleRightMargin);
    self.mainView.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.mainView.layer.shadowOffset = CGSizeMake(6, 6);
    self.mainView.layer.shadowOpacity = 0.7;
    self.mainView.autoresizesSubviews = YES;

    // Removed corners due to issue #19051, flickers when keyboard is over

    // setup as clickable background view
    self.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    self.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.5];
    self.layer.cornerRadius = 0;

    // Tapping outside closes the popup - Keeping code as a safe behavior on connectivity issues
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doneButtonPushed:)];
    tapGesture.delegate = self;
    [self addGestureRecognizer:tapGesture];
}

#pragma mark - Layout
/*
 * Being called when the view is being drawn
 *
 * Note: You should not call this method directly. If you want to force a layout update, call the setNeedsLayout method instead
 */
- (void)layoutSubviews {
    TPLog(@"layoutSubviews");
    [super layoutSubviews];

    UIApplication *application = [UIApplication sharedApplication];
    float statusBarHeight = MIN(application.statusBarFrame.size.width, application.statusBarFrame.size.height);

    // Setup margins for popup
    CGFloat horizontalMargin = 0;
    CGFloat verticalMargin = 0;
    if (self.viewMode == TPViewModePopup) {
        horizontalMargin = popupHorizontalMargin;
        verticalMargin = popupVerticalMargin;
    }

    // ViewController::edgesForExtendedLayout is not working, so we will need to move the start y on ios7, possible reasons:
    // - we are drawing the view ourselves, and we were supposed to use the property ourselves, its not clear from iOS SDK documentation
    // - the property is not working as expected, an iOS SDK issue
    float startY = 0;

    // iOS 7 changes handling of status bar, this prevents "views under status bar"
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        startY = statusBarHeight;
    }

    // At this point we may have a transform (only self, subviews are not transformed)...
    // If we dont set to identity transform, all rotation animations break.
    CGAffineTransform currentTransform = self.transform;
    self.transform = CGAffineTransformIdentity;

    // Change data to landscape if needed
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UIDeviceOrientationIsLandscape(orientation)) {
        CGFloat temp = horizontalMargin;
        horizontalMargin = verticalMargin;
        verticalMargin = temp;
    }

    if (self.mainView == nil) {
        CGRect screenRect =  [[UIScreen mainScreen] bounds];
        // we need to get the screen size with the right orientation which means to get the height and width
        // and then to switch their positions if (we got a landscape orientation)XOR(we need landscape orientation)
        // we do that here with two replace statements

        CGFloat height = screenRect.size.height;
        CGFloat width = screenRect.size.width;

        if (UIDeviceOrientationIsLandscape(orientation)) {
            TPLog(@"Switch");
            CGFloat temp = width;
            width = height;
            height = temp;
        }

        TPLog(@"height: %f, width: %f", height, width);

        [self buildViewWithNavigationBarAndWidth:width height:height-statusBarHeight];

        if (self.initialUrl) {
            NSURL *url = [NSURL URLWithString:self.initialUrl];
            NSURLRequest* request = [NSURLRequest requestWithURL:url];
            [self.offerwallContainer loadRequest:request];
            self.webViewContainer = self.offerwallContainer;
        }

        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
            // TODO: presuming offerwall status bar should always be white...
            self.backgroundColor = [UIColor whiteColor]; // will be reset by popup
        }

        if (self.viewMode == TPViewModePopup) {
            [self setupAsPopup];
        }

        [self addSubview:self.mainView];

    }

    // Force apply rotation animation by resetting transforms
    self.transform = prevTransform;
    self.transform = currentTransform;

    // Adjust bounds when rotated on popup mode - for some reason unlike in fullscreen the view does not get resized
    CGFloat mainWidth = self.bounds.size.width - horizontalMargin * 2;
    CGFloat mainHeight = self.bounds.size.height - verticalMargin * 2 - startY;
    if (self.viewMode == TPViewModePopup) {
        
        mainHeight-=offerwallContainerSizeDelta.height;
        verticalMargin += offerwallContainerSizeDelta.height/2;
        
        mainWidth-=offerwallContainerSizeDelta.width;
        horizontalMargin += offerwallContainerSizeDelta.width/2;
        
        self.mainView.bounds = CGRectMake(0, 0, mainWidth, mainHeight);
    }

    // on iOS7 the frame needs to be moved as well.
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        self.mainView.frame = CGRectMake(horizontalMargin, verticalMargin + startY, mainWidth, mainHeight);
    }
    prevTransform = currentTransform;

    TPLog(@"> self.frame      %@", NSStringFromCGRect(self.frame));
    TPLog(@"> self bounds     %@", NSStringFromCGRect(self.bounds));
    TPLog(@"> mainView frame  %@", NSStringFromCGRect(self.mainView.frame));
    TPLog(@"> mainView bounds %@", NSStringFromCGRect(self.mainView.bounds));
}

#pragma mark - Loading offers
- (void)loadOfferContainerWithRequest:(NSURLRequest *)request {
    TPLog(@"loadOfferContainerWithRequest: %@", request.URL.absoluteString);
    
    self.offerContainer = [[[UIWebView alloc] initWithFrame:self.offerwallContainer.frame] TP_AUTORELEASE];
    
    self.offerContainer.alpha = 1.000;
    self.offerContainer.autoresizesSubviews = YES;
    self.offerContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.offerContainer.backgroundColor = [UIColor colorWithRed:1.000 green:1.000 blue:1.000 alpha:1.000];
    self.offerContainer.clearsContextBeforeDrawing = YES;
    self.offerContainer.clipsToBounds = NO;
    self.offerContainer.contentMode = UIViewContentModeScaleToFill;
    self.offerContainer.hidden = NO;
    self.offerContainer.multipleTouchEnabled = NO;
    self.offerContainer.opaque = YES;
    self.offerContainer.scalesPageToFit = NO;
    self.offerContainer.tag = 0;
    self.offerContainer.userInteractionEnabled = YES;
    self.offerContainer.delegate = self;

    [self.offerContainer setAllowsInlineMediaPlayback:YES];
    [self.offerContainer setMediaPlaybackRequiresUserAction:NO];
    [self.offerContainer setScalesPageToFit:YES];
    
    [self.offerContainer loadRequest:request];
    
    void (^animationBlock)(void) = ^{
        [self.mainView addSubview:self.offerContainer];
    };
    [UIView transitionWithView:self.mainView
                      duration:0.5
                      options:UIViewAnimationOptionTransitionCrossDissolve
                      animations:[[animationBlock copy] TP_AUTORELEASE]
                    completion:^(BOOL a){
                        [TpUtils singleFlowUnlockWithMessage:@"loadDetails"];
                    }];
    
    self.webViewContainer = self.offerContainer;
    [self setupNavigationBarUsingBack:YES];
}

- (void)setupNavigationBarUsingBack:(BOOL)useBack {
    if (useBack) {
        self.navigationBar.items = [NSArray arrayWithObjects:self.backButton, self.flexibleSpaceArea, self.doneButton, nil];
    } else {
        self.navigationBar.items = [NSArray arrayWithObjects:self.flexibleSpaceArea, self.doneButton, nil];
    }
}

- (void)unloadOfferContainer {
    TPLog(@"unloadOfferContainer");
    self.webViewContainer = self.offerwallContainer;
    [self.offerContainer removeFromSuperview];
    self.offerContainer = nil;
    [self setupNavigationBarUsingBack:NO];
    [self.webNavigationBar onSDKEvent:@{kTPSDKEventTypeKey: kTPSDKEventTypeContainerStatusChanged,
                                        kTPSDKEventSourceKey: kTPOfferContainer,
                                        kTPSDKEventNewStatusKey: kTPSDKEventStatusClosed}];
}

#pragma mark - Indicator on Navigation Bar
- (void)showLoadingIndicator {
    if ([[BaseTrialpayManager sharedInstance] useWebNavigationBar]) {
        [self.webNavigationBar showSpinner];
    } else {
        if (nil == self.loadingIndicator) {
            CGRect indicatorBounds = CGRectMake(self.offerwallContainer.frame.size.width/4, 12, self.offerwallContainer.frame.size.width/2, 24);
            self.loadingIndicator = [[[UIActivityIndicatorView alloc] initWithFrame:indicatorBounds] TP_AUTORELEASE];
            self.loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
            self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [self.loadingIndicator startAnimating];
            [self.mainView addSubview:self.loadingIndicator];
        }
    }
}

- (void)hideLoadingIndicator {
    if ([[BaseTrialpayManager sharedInstance] useWebNavigationBar]) {
        [self.webNavigationBar hideSpinner];
    } else {
        if (nil != self.loadingIndicator) {
            [self.loadingIndicator removeFromSuperview];
            self.loadingIndicator = nil;
        }
    }
}

#pragma mark - webView (UIWebViewDelegate)
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    self.currentRequest = request;
    TPLog(@"webView:%@ shouldStartLoadWithRequest:%@ navigationType:%d", [self getWebViewName:webView], [[request URL] absoluteString], (int)navigationType);
    
    if ([webView isEqual:self.offerwallContainer]) {
        if ([request.URL.scheme hasPrefix:@"http"] || [request.URL.scheme hasPrefix:@"https"]) {
            NSArray *tpHosts = [NSArray arrayWithObjects:@"trialpay.com", @"trialpay.net", @"tp-cdn.com", nil];
            
            NSString *host = request.URL.host;

            BOOL isTPHost = NO;
            for (NSString *tpHost in tpHosts) {
                if ([host rangeOfString:tpHost].location != NSNotFound) {
                    isTPHost = YES;
                    break;
                }
            }
            
            if (isTPHost) {
                // when loading a new page, start by checking if it is a tp_base_page. These pages should be loaded in the offerwallContainer
                if ([request.URL.absoluteString rangeOfString:@"tp_base_page=1"].location != NSNotFound) {
                    return YES;
                } else {
                    if ([TpUtils singleFlowLockWithMessage:@"loadDetails"]) {
                        [self loadOfferContainerWithRequest:request];
                    }
                    return NO;
                }
            } else {
                return YES;
            }
        }
    } else if ([webView isEqual:self.offerContainer]) {
        // we need to see if the URL has a special protocol. if not, load the page in the offerContainer
        if ([request.URL.scheme hasPrefix:@"http"] || [request.URL.scheme hasPrefix:@"https"]) {
            return YES;
        }
    } else {
        // If we got here that means that there's a page that the offerContainer attempts to open but it is already dismissed
        // in this scenario we will just skip loading
        return NO;
    }

    // handle the special protocol "tp://"
    if ([request.URL.scheme hasPrefix:@"tp"]) {
        if ([request.URL.host isEqualToString:@"navbar_js"]) {
            // it's a command that the OfferWallContainer or the OfferContainer sent to the navbar
            // (in this case the request has the format "tp://navbar_js/[js_method_name]([param_a], [param_b]...)", e.g. "tp://navbar_js/showSpinner()")
            NSArray *pathComponents = request.URL.pathComponents;

            // make sure that path components contain only two elements: "/" and command
            if (pathComponents.count == 2) {
                // extract a JavaScript command and ask the navbar to execute it
                NSString *jsCommand = [TpUrlManager URLDecodeQueryString:[pathComponents objectAtIndex:1]];
                [self.webNavigationBar executeCommand:jsCommand];
            }
            return NO;
        }
        else if ([request.URL.host isEqualToString:@"adjustSize"]) {
            [self adjustOfferwallContainerSize];
            return NO;
        }
    }

    // if the special protocol starts with "tpvideo", stop the URL load and open the video within our video trailer flow.
    if ([request.URL.absoluteString hasPrefix:kTPKeyVideoPrefix]) {
        NSString *videoResourceURL = [request.URL.absoluteString substringFromIndex:[kTPKeyVideoPrefix length]];
        if ([TpUtils singleFlowLockWithMessage:@"playVideo"]) {
            [self.delegate playVideoWithURL:videoResourceURL];
        }
        return NO;
    }

    // if the special protocol starts with "tpbowhttp(s)", remove tpbow prefix. it was needed only in order to skip the offerContainer
    NSURL *url = request.URL;
    if ([request.URL.scheme hasPrefix:@"tpbow"]) {
        url = [NSURL URLWithString:[request.URL.absoluteString substringFromIndex:5]];
    }
    if ([self externalAppOpener] == nil) {
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
            return NO;
        }
    } else {
        [self externalAppOpener](url);
    }
    return NO;
}


- (void)webViewDidStartLoad:(UIWebView *)webView {
    TPLog(@"webViewDidStartLoad %@", [self getWebViewName:webView]);
    [self showLoadingIndicator];
    [self.webNavigationBar onSDKEvent:@{kTPSDKEventTypeKey: kTPSDKEventTypePageStatusChanged,
                                        kTPSDKEventSourceKey: [self getWebViewName:webView],
                                        kTPSDKEventNewStatusKey: kTPSDKEventStatusLoadingStarted,
                                        kTPSDKEventURLKey: self.currentRequest.URL.absoluteString}];
    
    //reset size adjustments for offerwallContainer
    offerwallContainerSizeDelta = CGSizeMake(0, 0);
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    TPLog(@"webViewDidFinishLoad %@", [self getWebViewName:webView]);
    [self hideLoadingIndicator];
    [self.webNavigationBar onSDKEvent:@{kTPSDKEventTypeKey: kTPSDKEventTypePageStatusChanged,
                                        kTPSDKEventSourceKey: [self getWebViewName:webView],
                                        kTPSDKEventNewStatusKey: kTPSDKEventStatusLoadingFinished,
                                        kTPSDKEventURLKey: webView.request.URL.absoluteString}];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if ([error code] == NSURLErrorCancelled) {
        return;
    }

    // Ignore/suppress "Fame Load Interrupted" errors. Seen after app store links.
    // couldnt find a enum code for 102
    if (error.code == 102 && [error.domain isEqual:@"WebKitErrorDomain"]) return;

    //Log this error even when not in DEBUG mode
    TPCustomerError(@"webView:didFailLoadWithError:", @"webView:%@ didFailLoadWithError:%@", [self getWebViewName:webView], [error description]);
    [self hideLoadingIndicator];
    switch ([error code]) {
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorTimedOut:
        {
            // The Internet connection appears to be offline
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"There seems to be a problem with your internet connection",@"There seems to be a problem with your internet connection")
                                                            message:NSLocalizedString(@"Would you like to try to reload the page?",@"Would you like to try to reload the page?")
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"Reload",@"Reload"), NSLocalizedString(@"Close",@"Close"), nil];
            [alert setTag:1];
            [alert show];
            [alert TP_AUTORELEASE];
            break;
        }
        default: break;
    }
    
}

#pragma mark - Buttons
/** Done button pushed - for done button selector */
- (IBAction)doneButtonPushed:(id)sender {
    TPLogEnter;
    [self hideLoadingIndicator];
    if ([self.webViewContainer isEqual:self.offerContainer]) {
        [self unloadOfferContainer];
    } else {
        [self.delegate tpWebView:self donePushed:sender];
    }
}

/** Back button pushed - for back button selector */
- (IBAction)backButtonPushed:(id)sender {
    TPLogEnter;
    [self hideLoadingIndicator];
    if (self.webViewContainer.canGoBack) {
        [self.webViewContainer goBack];
    } else {
        [self doneButtonPushed:sender];
    }
}

#pragma mark - Alert view delegate (connection issues)
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (alertView.tag) {
        case 1:
        {
            switch (buttonIndex) {
                case 0: //Reload
                {
                    if (self.webViewContainer.canGoBack) {
                        [self.webViewContainer reload];
                    } else {
                        if ([self.webViewContainer isEqual:self.offerwallContainer] ) {
                            NSURL *url = [NSURL URLWithString:self.initialUrl];
                            NSURLRequest *request = [NSURLRequest requestWithURL:url];
                            [self.offerwallContainer loadRequest:request];
                        } else {
                            [self doneButtonPushed:nil]; //TODO: this needs to be fixed - reload does not work for the initial URL
                        }
                    }
                    break;
                }
                case 1: //Close
                {
                    [self doneButtonPushed:nil];
                    break;
                }
                default: break;
            }
            break;
        }
        default: break;
    }
}

- (BOOL)loadWebViewTouchpoint:(NSString *)touchpointName {
    TPLogEnter;
    self.currentTouchpointName = touchpointName;
    NSString *url = [[TpUrlManager sharedInstance] offerwallUrlForTouchpoint:touchpointName];
    TPLog(@"Url: %@", url);
    if (url == nil) {
        TPCustomerLog(@"Unable to get offerwall URL for {url}", @"Unable to get offerwall URL for %@", touchpointName);
        return false;
    }
    [self unloadOfferContainer];
    [self loadRequest:url];
    return true;
}

// Respond to tp://close - call the close offerwall functionality
- (void) navClose:(NSString *)dummy {
    [self.delegate tpWebView:self donePushed:self];
}

//tp://up - call the "up" functionality - if the user is in the offer scope, go back to the offerwall, otherwise close the offerwall
- (void) navUp:(NSString *)dummy {
    [self hideLoadingIndicator];
    // go up, than close
    if ([self.webViewContainer isEqual:self.offerContainer]) {
        [self unloadOfferContainer];
    } else {
        [self.delegate tpWebView:self donePushed:self];
    }
// OR Should we just be done:
// [self doneButtonPushed:self];
}

//tp://back - browser-back
- (void) navBack:(NSString *)dummy {
    [self backButtonPushed:self];
}

//tp://reload - reload the offerwall (clear browsing history)
- (void) navReload:(NSString *)dummy {
    // well, lets reload the current webview, resetting the cache
    [TpUrlManager clearHTTPCache];
    [self loadWebViewTouchpoint:self.currentTouchpointName];
}

//tp://refresh - reload the current page
- (void) navRefresh:(NSString *)dummy {
    [self.webViewContainer loadRequest:self.currentRequest];
}

//tp://offerwall/[url] - open [url] in the OfferWallContainer. being used with the protocol tp://offerwall/http://www.google.com
- (void) navOfferwall:(NSString *)urlString {
    TPLog(@"open owURL %@", urlString);
    if ([self.webViewContainer isEqual:self.offerContainer]) {
        [self unloadOfferContainer];
    }
    // webViewContainer is now the offerwallContainer
    [self.webViewContainer loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
}

//tp://offer/[url] - open [url] in the Offer. being used with the protocol tp://offerwall/http://www.google.com
- (void) navOffer:(NSString *)urlString {
    TPLog(@"open offerURL %@", urlString);
    if ([self.webViewContainer isEqual:self.offerContainer]) {
        // webViewContainer is now the offerContainer
        [self.webViewContainer loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
    } else {
        [self loadOfferContainerWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
    }
}

//tp://changeNavBarHeight/[height] - set the header height to [height] (pixel density = 1)
- (void) navChangeNavBarHeight:(NSString *)heightString {
    int height = [heightString intValue];
    TPLog(@"New height is %d", height);

    
    CGRect navbarFrame = self.webNavigationBar.frame;
    CGFloat offset = height - navbarFrame.size.height;
    navbarFrame.size.height += offset;
    TPLog(@"web navigationBar %@", NSStringFromCGRect(navbarFrame));
    self.webNavigationBar.frame = navbarFrame;
    TPLog(@"web navigationBar %@", NSStringFromCGRect(self.webNavigationBar.frame));
    
    CGRect webFrame = self.webViewContainer.frame;
    webFrame.origin = CGPointMake(webFrame.origin.x, webFrame.origin.y + offset);
    webFrame.size.height -= offset;
    TPLog(@"web container frame %@", NSStringFromCGRect(webFrame));
    self.webViewContainer.frame = webFrame;
    TPLog(@"web container frame %@", NSStringFromCGRect(self.webViewContainer.frame));
    
}

- (void)navLoaded:(NSString *)dummy {
    TPLogEnter;
    self.navigationBar.hidden = YES;
    self.webNavigationBar.hidden = NO;
}

// stop webviews clearing its delegates first
- (void)stopWebViews {
    TPLogEnter;
    self.offerwallContainer.delegate = nil;
    [self.offerwallContainer stopLoading];
    self.offerContainer.delegate = nil;
    [self.offerContainer stopLoading];

    [self.webNavigationBar stopWebView];
    
    // this is mostly to help seeing release calls when tracing memory leaks
    self.offerwallContainer = nil;
    self.offerContainer = nil;
    self.webViewContainer = nil;
    self.webNavigationBar = nil;
}

- (void)adjustOfferwallContainerSize
{
    if (self.offerwallContainer != nil && self.viewMode == TPViewModePopup) {
        // reset old ajustments
        offerwallContainerSizeDelta = CGSizeMake(0, 0);
        [self setNeedsLayout];
        // force layout
        [self layoutIfNeeded];
        
        CGRect originaFrame = self.offerwallContainer.frame;
        
        [self.offerwallContainer stringByEvaluatingJavaScriptFromString:@"window.setAdjustMode()"];
        
        CGFloat width = [[self.offerwallContainer stringByEvaluatingJavaScriptFromString:@"document.documentElement.offsetWidth"] floatValue];
        CGFloat height = [[self.offerwallContainer stringByEvaluatingJavaScriptFromString:@"document.documentElement.offsetHeight"] floatValue];
        
        CGSize fittingSize = CGSizeMake(width, height);
        
        if (fittingSize.height < originaFrame.size.height && !CGSizeEqualToSize(fittingSize, CGSizeMake(0, 0)))
            offerwallContainerSizeDelta.height = originaFrame.size.height - fittingSize.height;
        else
            offerwallContainerSizeDelta.height = 0;
        
        if (fittingSize.width < originaFrame.size.width && !CGSizeEqualToSize(fittingSize, CGSizeMake(0, 0)))
            offerwallContainerSizeDelta.width = originaFrame.size.width - fittingSize.width;
        else
            offerwallContainerSizeDelta.width = 0;
        
        [self setNeedsLayout];
    }
    else
        offerwallContainerSizeDelta = CGSizeMake(0, 0);
}

@end
