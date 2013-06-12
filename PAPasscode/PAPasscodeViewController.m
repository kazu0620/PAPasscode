//
//  PAPasscodeViewController.m
//  PAPasscode
//
//  Created by Denis Hennessy on 15/10/2012.
//  Copyright (c) 2012 Peer Assembly. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "PAPasscodeViewController.h"

#define NAVBAR_HEIGHT   44
#define PROMPT_BG_HEIGHT    35
#define PROMPT_LABEL_HEIGHT 20
#define MARGIN_VIEW_TOP 20
#define DIGIT_SPACING   10
#define DIGIT_WIDTH     61
#define DIGIT_HEIGHT    53
#define MARKER_WIDTH    16
#define MARKER_HEIGHT   16
#define MARKER_X        22
#define MARKER_Y        18
#define MESSAGE_HEIGHT  74
#define FAILED_LCAP     19
#define FAILED_RCAP     19
#define FAILED_HEIGHT   35
#define FAILED_MARGIN   10
#define TEXTFIELD_MARGIN 8
#define SLIDE_DURATION  0.3

@interface PAPasscodeViewController ()
- (void)cancel:(id)sender;
- (void)handleFailedAttempt;
- (void)handleCompleteField;
- (void)passcodeChanged:(id)sender;
- (void)resetFailedAttempts;
- (void)showFailedAttempts;
- (void)showScreenForPhase:(NSInteger)phase animated:(BOOL)animated;
@end

@implementation PAPasscodeViewController

- (id)initForAction:(PasscodeAction)action {
    self = [super init];
    if (self) {
        _action = action;
        switch (action) {
            case PasscodeActionSet:
                self.title = NSLocalizedString(@"Set Passcode", nil);
                _enterPrompt = NSLocalizedString(@"Enter a passcode", nil);
                _confirmPrompt = NSLocalizedString(@"Re-enter your passcode", nil);
                break;
                
            case PasscodeActionSetDummyPassword:
                self.title = NSLocalizedString(@"Set Dummy Passcode", nil);
                _enterPrompt = NSLocalizedString(@"Enter a dummy passcode", nil);
                _confirmPrompt = NSLocalizedString(@"Re-enter your dummy passcode", nil);
                break;
                
                
            case PasscodeActionEnter:
                self.title = NSLocalizedString(@"Enter Passcode", nil);
                _enterPrompt = NSLocalizedString(@"Enter your passcode", nil);
                break;
                
            case PasscodeActionChange:
                self.title = NSLocalizedString(@"Change Passcode", nil);
                _changePrompt = NSLocalizedString(@"Enter your old passcode", nil);
                _enterPrompt = NSLocalizedString(@"Enter your new passcode", nil);
                _confirmPrompt = NSLocalizedString(@"Re-enter your new passcode", nil);
                break;
        }
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        _simple = YES;
        _isDisplayNavigationBar = NO;
        _isDisplayMessageAnimation = NO;
        _isDisplayMessageText = YES;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    return self;
}

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    NSInteger contentViewHeigt = view.bounds.size.height;
    NSInteger contentViewY     = 0;
    
    if(_isDisplayNavigationBar){
        UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, view.bounds.size.width, NAVBAR_HEIGHT)];
        navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        navigationBar.items = @[self.navigationItem];
        [view addSubview:navigationBar];
        contentViewHeigt = contentViewHeigt + NAVBAR_HEIGHT;
        contentViewY = NAVBAR_HEIGHT;
    }

    contentView = [[UIView alloc] initWithFrame:CGRectMake(0, contentViewY, view.bounds.size.width, contentViewHeigt)];
    contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    if (_backgroundView) {
        [contentView addSubview:_backgroundView];
    }
    contentView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    [view addSubview:contentView];
    
    CGFloat panelWidth = DIGIT_WIDTH*4+DIGIT_SPACING*3;
    if (_simple) {
        UIView *digitPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelWidth, DIGIT_HEIGHT)];
        digitPanel.frame = CGRectOffset(digitPanel.frame, (contentView.bounds.size.width-digitPanel.bounds.size.width)/2, MARGIN_VIEW_TOP + _lockedImageView.bounds.size.height + 20);
        digitPanel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
        [contentView addSubview:digitPanel];
        
        UIImage *backgroundImage = [UIImage imageNamed:@"papasscode_background"];
        UIImage *markerImage = [UIImage imageNamed:@"papasscode_marker"];
        CGFloat xLeft = 0;
        for (int i=0;i<4;i++) {
            UIImageView *backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
            backgroundImageView.frame = CGRectOffset(backgroundImageView.frame, xLeft, 0);
            [digitPanel addSubview:backgroundImageView];
            digitImageViews[i] = [[UIImageView alloc] initWithImage:markerImage];
            digitImageViews[i].autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
            digitImageViews[i].frame = CGRectOffset(digitImageViews[i].frame, backgroundImageView.frame.origin.x+MARKER_X, MARKER_Y);
            [digitPanel addSubview:digitImageViews[i]];
            xLeft += DIGIT_SPACING + backgroundImage.size.width;
        }
        passcodeTextField = [[UITextField alloc] initWithFrame:digitPanel.frame];
        passcodeTextField.hidden = YES;
    } else {
        UIView *passcodePanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelWidth, DIGIT_HEIGHT)];
        passcodePanel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
        passcodePanel.frame = CGRectOffset(passcodePanel.frame, (contentView.bounds.size.width-passcodePanel.bounds.size.width)/2, MARGIN_VIEW_TOP);
        passcodePanel.frame = CGRectInset(passcodePanel.frame, TEXTFIELD_MARGIN, TEXTFIELD_MARGIN);
        passcodePanel.layer.borderColor = [UIColor colorWithRed:0.65 green:0.67 blue:0.70 alpha:1.0].CGColor;
        passcodePanel.layer.borderWidth = 1.0;
        passcodePanel.layer.cornerRadius = 5.0;
        passcodePanel.layer.shadowColor = [UIColor whiteColor].CGColor;
        passcodePanel.layer.shadowOffset = CGSizeMake(0, 1);
        passcodePanel.layer.shadowOpacity = 1.0;
        passcodePanel.layer.shadowRadius = 1.0;
        passcodePanel.backgroundColor = [UIColor whiteColor];
        [contentView addSubview:passcodePanel];
        passcodeTextField = [[UITextField alloc] initWithFrame:CGRectInset(passcodePanel.frame, 6, 6)];
    }
    
    [self drawPromptMessage];
    
    passcodeTextField.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    passcodeTextField.borderStyle = UITextBorderStyleNone;
    passcodeTextField.secureTextEntry = YES;
    passcodeTextField.textColor = [UIColor colorWithRed:0.23 green:0.33 blue:0.52 alpha:1.0];
    passcodeTextField.keyboardType = UIKeyboardTypeNumberPad;
    passcodeTextField.keyboardAppearance = UIKeyboardAppearanceAlert;
    [passcodeTextField addTarget:self action:@selector(passcodeChanged:) forControlEvents:UIControlEventEditingChanged];
    [contentView addSubview:passcodeTextField];

    if(_lockedImageView){
        _lockedImageView.frame = CGRectOffset(_lockedImageView.frame, (contentView.bounds.size.width - _lockedImageView.bounds.size.width) / 2, MARGIN_VIEW_TOP);
        [contentView addSubview:_lockedImageView];
    }
    
  
    messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, MARGIN_VIEW_TOP + DIGIT_HEIGHT, contentView.bounds.size.width, MESSAGE_HEIGHT)];
    messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    messageLabel.backgroundColor = [UIColor clearColor];
    messageLabel.textColor = [UIColor colorWithRed:0.30 green:0.34 blue:0.42 alpha:1.0];
    messageLabel.font = [UIFont systemFontOfSize:14];
    messageLabel.shadowColor = [UIColor whiteColor];
    messageLabel.shadowOffset = CGSizeMake(0, 1);
    messageLabel.textAlignment = NSTextAlignmentCenter;
    messageLabel.numberOfLines = 0;
	messageLabel.text = _message;
    [contentView addSubview:messageLabel];
    
    failedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, FAILED_HEIGHT)];
    failedImageView.backgroundColor = [UIColor redColor];
    failedImageView.hidden = YES;
    failedImageView.alpha = 0.5f;
    [contentView addSubview:failedImageView];
    
    failedAttemptsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    failedAttemptsLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    failedAttemptsLabel.backgroundColor = [UIColor clearColor];
    failedAttemptsLabel.textColor = [UIColor whiteColor];
    failedAttemptsLabel.font = [UIFont boldSystemFontOfSize:15];
    failedAttemptsLabel.shadowColor = [UIColor blackColor];
    failedAttemptsLabel.shadowOffset = CGSizeMake(0, -1);
    failedAttemptsLabel.textAlignment = NSTextAlignmentCenter;
    
    failedAttemptsLabel.hidden = YES;
    [contentView addSubview:failedAttemptsLabel];
    
    if( _action == PasscodeActionSet
       || _action == PasscodeActionSetDummyPassword
       || _action ==  PasscodeActionChange
       ){ [self _renderCloseButton]; }
    
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([_delegate respondsToSelector:@selector(PAPasscodeViewControllerDidCancel:)]) {
        if (_simple) {
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
        } else {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
        }
    }
    
    if (_failedAttempts > 0) {
        [self showFailedAttempts];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self showScreenForPhase:0 animated:NO];
    [passcodeTextField becomeFirstResponder];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait|UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (void)cancel:(id)sender {
    [_delegate PAPasscodeViewControllerDidCancel:self];
}

#pragma mark - implementation helpers

- (void)handleCompleteField {
    NSString *text = passcodeTextField.text;
    switch (_action) {
        case PasscodeActionSet:
            if (phase == 0) {
                _passcode = text;
                messageLabel.text = @"";
                [self resetFailedAttempts];
                [self showScreenForPhase:1 animated:YES];
            } else {
                if ([text isEqualToString:_passcode]) {
                    if ([_delegate respondsToSelector:@selector(PAPasscodeViewControllerDidSetPasscode:)]) {
                        [_delegate PAPasscodeViewControllerDidSetPasscode:self];
                    }
                } else {
                    [self showScreenForPhase:0 animated:YES];
                    [self showPasswordUnmatch];
                }
            }
            break;
            
        case PasscodeActionSetDummyPassword:
            if (phase == 0) {
                _dummyPasscode = text;
                messageLabel.text = @"";
                [self resetFailedAttempts];
                [self showScreenForPhase:1 animated:YES];
            } else {
                if ([text isEqualToString:_dummyPasscode]) {
                    if ([_delegate respondsToSelector:@selector(PAPasscodeViewControllerDidSetPasscode:)]) {
                        [_delegate PAPasscodeViewControllerDidSetDummyPasscode:self];
                    }
                } else {
                    [self showScreenForPhase:0 animated:YES];
                    [self showPasswordUnmatch];
                }
            }
            break;
            
        case PasscodeActionEnter:
            if ([text isEqualToString:_passcode]) {
                [self resetFailedAttempts];
                if ([_delegate respondsToSelector:@selector(PAPasscodeViewControllerDidEnterPasscode:)]) {
                    [_delegate PAPasscodeViewControllerDidEnterPasscode:self];
                }
            }else if ([text isEqualToString:_dummyPasscode]) {
                [self resetFailedAttempts];
                if ([_delegate respondsToSelector:@selector(PAPasscodeViewControllerDidEnterDummyPasscode:)]) {
                    [_delegate PAPasscodeViewControllerDidEnterDummyPasscode:self];
                }
            }else {
                if (_alternativePasscode && [text isEqualToString:_alternativePasscode]) {
                    [self resetFailedAttempts];
                    if ([_delegate respondsToSelector:@selector(PAPasscodeViewControllerDidEnterAlternativePasscode:)]) {
                        [_delegate PAPasscodeViewControllerDidEnterAlternativePasscode:self];
                    }
                } else {
                    [self handleFailedAttempt];
                    [self showScreenForPhase:0 animated:NO];
                }
            }
            break;
            
        case PasscodeActionChange:
            if (phase == 0) {
                if ([text isEqualToString:_passcode]) {
                    [self resetFailedAttempts];
                    [self showScreenForPhase:1 animated:YES];
                } else {
                    [self handleFailedAttempt];
                    [self showScreenForPhase:0 animated:NO];
                }
            } else if (phase == 1) {
                _passcode = text;
                messageLabel.text = @"";
                [self resetFailedAttempts];
                [self showScreenForPhase:2 animated:YES];
            } else {
                if ([text isEqualToString:_passcode]) {
                    if ([_delegate respondsToSelector:@selector(PAPasscodeViewControllerDidChangePasscode:)]) {
                        [_delegate PAPasscodeViewControllerDidChangePasscode:self];
                    }
                } else {
                    [self showScreenForPhase:1 animated:YES];
                    [self showPasswordUnmatch];
                }
            }
            break;
    }
}

- (void)handleFailedAttempt {
    _failedAttempts++;
    [self showFailedAttempts];
    if ([_delegate respondsToSelector:@selector(PAPasscodeViewController:didFailToEnterPasscode:)]) {
        [_delegate PAPasscodeViewController:self didFailToEnterPasscode:_failedAttempts];
    }
}

- (void)resetFailedAttempts {
    messageLabel.hidden = NO;
    failedImageView.hidden = YES;
    failedAttemptsLabel.hidden = YES;
    _failedAttempts = 0;
}

- (void)showPasswordUnmatch{
    failedAttemptsLabel.text = NSLocalizedString(@"Passcodes did not match. Try again.", nil);
    [self showWarningTextView];
}

- (void)showFailedAttempts {
    if (_failedAttempts == 1) {
        failedAttemptsLabel.text = NSLocalizedString(@"1 Failed Passcode Attempt", nil);
    } else {
        failedAttemptsLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d Failed Passcode Attempts", nil), _failedAttempts];
    }
    [self showWarningTextView];
}

- (void)showWarningTextView {
    messageLabel.hidden = YES;
    failedImageView.hidden = NO;
    failedAttemptsLabel.hidden = NO;
    [failedAttemptsLabel sizeToFit];
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat bgWidth = screenBounds.size.width;
    
    CGFloat x = floor((contentView.bounds.size.width-bgWidth)/2);
    CGFloat y = 0;
    x = failedImageView.frame.origin.x+FAILED_MARGIN;
    y = failedImageView.frame.origin.y+floor((failedImageView.bounds.size.height-failedAttemptsLabel.frame.size.height)/2);
    failedAttemptsLabel.frame = CGRectMake(x, y, failedAttemptsLabel.bounds.size.width, failedAttemptsLabel.bounds.size.height);
    
}

- (void)passcodeChanged:(id)sender {
    NSString *text = passcodeTextField.text;
    if (_simple) {
        if ([text length] > 4) {
            text = [text substringToIndex:4];
        }
        for (int i=0;i<4;i++) {
            digitImageViews[i].hidden = i >= [text length];
        }
        if ([text length] == 4) {
            [self handleCompleteField];
        }
    } else {
        self.navigationItem.rightBarButtonItem.enabled = [text length] > 0;
    }
}

- (void)showScreenForPhase:(NSInteger)newPhase animated:(BOOL)animated {
    CGFloat dir = (newPhase > phase) ? 1 : -1;
    if (animated) {
        UIGraphicsBeginImageContext(self.view.bounds.size);
        [contentView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        snapshotImageView = [[UIImageView alloc] initWithImage:snapshot];
        snapshotImageView.frame = CGRectOffset(snapshotImageView.frame, -contentView.frame.size.width*dir, 0);
        [contentView addSubview:snapshotImageView];
    }
    phase = newPhase;
    passcodeTextField.text = @"";
    if (!_simple) {
        BOOL finalScreen = _action == PasscodeActionSet && phase == 1;
        finalScreen |= _action == PasscodeActionSetDummyPassword && phase == 1;
        finalScreen |= _action == PasscodeActionEnter && phase == 0;
        finalScreen |= _action == PasscodeActionChange && phase == 2;
        if (finalScreen) {
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(handleCompleteField)];
        } else {
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", nil) style:UIBarButtonItemStyleBordered target:self action:@selector(handleCompleteField)];
        }
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
    
    switch (_action) {
        case PasscodeActionSet:
            if (phase == 0) {
                promptLabel.text = _enterPrompt;
            } else {
                promptLabel.text = _confirmPrompt;
            }
            break;
        case PasscodeActionSetDummyPassword:
            if (phase == 0) {
                promptLabel.text = _enterPrompt;
            } else {
                promptLabel.text = _confirmPrompt;
            }
            break;
            
        case PasscodeActionEnter:
            promptLabel.text = _enterPrompt;
            break;
            
        case PasscodeActionChange:
            if (phase == 0) {
                promptLabel.text = _changePrompt;
            } else if (phase == 1) {
                promptLabel.text = _enterPrompt;
            } else {
                promptLabel.text = _confirmPrompt;
            }
            break;
    }
    for (int i=0;i<4;i++) {
        digitImageViews[i].hidden = YES;
    }
    if (animated) {
        contentView.frame = CGRectOffset(contentView.frame, contentView.frame.size.width*dir, 0);
        [UIView animateWithDuration:SLIDE_DURATION animations:^() {
            contentView.frame = CGRectOffset(contentView.frame, -contentView.frame.size.width*dir, 0);
        } completion:^(BOOL finished) {
            [snapshotImageView removeFromSuperview];
            snapshotImageView = nil;
        }];
    }
}

- (void) keyboardDidShow:(NSNotification *)nsNotification {
    NSDictionary *userInfo = [nsNotification userInfo];
    CGSize kbSize = [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    keyboadHeight = kbSize.height;
    [self adjustPromptMessagePosition];
}

-(void)adjustPromptMessagePosition{
    CGFloat promptBgImageY = contentView.bounds.size.height - keyboadHeight - PROMPT_BG_HEIGHT;
    CGFloat promptLabelY   = promptBgImageY + floor((promptBgImageView.bounds.size.height - promptLabel.bounds.size.height) / 2);
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    
    if(!_isDisplayMessageAnimation){
        promptBgImageView.frame = CGRectMake(0, promptBgImageY, screenBounds.size.width, PROMPT_BG_HEIGHT);
        promptLabel.frame = CGRectMake(0, promptLabelY, contentView.bounds.size.width, PROMPT_LABEL_HEIGHT);
        return;
    }
    
    promptBgImageView.frame = CGRectMake(0, contentView.bounds.size.height - keyboadHeight, screenBounds.size.width, 0);
    promptLabel.frame = CGRectMake(0, contentView.bounds.size.height - keyboadHeight, contentView.bounds.size.width, 0);
    [UIView animateWithDuration:0.9f
        animations:^{
            promptBgImageView.frame = CGRectMake(0, promptBgImageY, screenBounds.size.width, PROMPT_BG_HEIGHT);
            promptLabel.frame = CGRectMake(0, promptLabelY, contentView.bounds.size.width, PROMPT_LABEL_HEIGHT);
        }
        completion:nil
    ];
    
}

- (void) drawPromptMessage{
    if(!_isDisplayMessageText){
        return;
    }
    
    if(promptLabel){
        return;
    }
    
    promptBgImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, PROMPT_BG_HEIGHT)];
    promptBgImageView.backgroundColor = _messageTextColor;
    promptBgImageView.alpha = 0.5f;
    [contentView addSubview:promptBgImageView];
       
    promptLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, PROMPT_LABEL_HEIGHT)];
    promptLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    promptLabel.backgroundColor = [UIColor clearColor];
    promptLabel.textColor = [UIColor whiteColor];
    promptLabel.font = [UIFont boldSystemFontOfSize:15];
    promptLabel.shadowColor = [UIColor blackColor];
    promptLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:promptLabel];
    
    return;
}

- (void) _renderCloseButton {

    UIImage *closeImage = [UIImage imageNamed:@"passcode_closebutton"];
    closeButton = [[UIButton alloc] initWithFrame:CGRectMake(
        contentView.frame.size.width - closeImage.size.width -10,
        10,
        closeImage.size.width,
        closeImage.size.height
    )];
    [closeButton setBackgroundImage: closeImage
                   forState:UIControlStateNormal];
    [closeButton addTarget:self
            action:@selector(onClickCloseButton:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:closeButton];
    
}

- (void)onClickCloseButton:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{}];
}


@end
