//
//  Created by stran on 3/2/12.
//
//


#import "PGWindow.h"
#import "PGTargetView.h"
#import "PGMenuView.h"
#import "PGInputView.h"


@implementation PGWindow {


}
@synthesize locked;
@synthesize menuView;


- (NSMutableArray *)viewsAtPoint:(CGPoint)touchPoint view:(UIView *)view {
    NSMutableArray *views = [[NSMutableArray alloc] init];
    for (UIView *subview in view.subviews) {
        if (CGRectContainsPoint(subview.frame, touchPoint)) {
            if (subview != overlayView && subview != targetView) {
                [views addObject:subview];
                [views addObjectsFromArray:[self viewsAtPoint:[view convertPoint:touchPoint toView:subview] view:subview]];
            }
        }
    }

    return [views autorelease];
}


- (UIView *)findTarget:(CGPoint)touchPoint {
    NSMutableArray *views = [self viewsAtPoint:touchPoint view:self.rootViewController.view];
    if ([views count] == 0) {
        return nil;
    }


    return [views lastObject];
}

- (void)deactivateTarget {
    [selectedView.superview insertSubview:selectedView atIndex:selectedIndex];
    selectedView = nil;

    menuView.target = nil;
    [menuView updateTargetInfo];

    [targetView removeFromSuperview];

    [inputView removeFromSuperview];
    [inputView deactivateKeyboard];

    [overlayView removeFromSuperview];
}

- (void)activateTarget:(UIView *)view {
    if (view == selectedView) {
        return;
    }

    [self deactivateTarget];

    if (view != self.rootViewController.view) {
        selectedIndex = [view.superview.subviews indexOfObject:view];
        selectedView = view;

        if (!overlayView) {
            overlayView = [[UIView alloc] initWithFrame:self.frame];
            overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            overlayView.backgroundColor = [UIColor blackColor];
            overlayView.alpha = 0.5;
        }
        if (!targetView) {
            targetView = [[PGTargetView alloc] initWithFrame:self.frame];
        }
        if (!inputView) {
            inputView = [[PGInputView alloc] initWithFrame:CGRectMake(-1, -1, 1, 1)];
            inputView.delegate = self;
        }

        menuView.target = selectedView;
        targetView.target = selectedView;
        overlayView.frame = targetView.frame;

        [view.superview bringSubviewToFront:selectedView];
        [view.superview insertSubview:overlayView belowSubview:selectedView];
        [view.superview addSubview:targetView];

        [menuView updateTargetInfo];
        [targetView setNeedsDisplay];

        [self addSubview:inputView];
        [inputView activateKeyboard];
    }

}

- (void)rotateGesture:(UIGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        self.locked = !locked;

        UILabel *label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
        label.backgroundColor = [UIColor blackColor];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = UITextAlignmentCenter;
        label.font = [UIFont boldSystemFontOfSize:25];
        label.layer.cornerRadius = 5;

        if (locked) {
            label.text = @"Locked";
        } else {
            label.text = @"Unlocked";
        }

        CGRect frame = self.rootViewController.view.bounds;

        [label sizeToFit];
        label.frame = CGRectInset(label.frame, -40, -20);
        label.center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));

        [self.rootViewController.view addSubview:label];
        [UIView animateWithDuration:1 delay:1 options:UIViewAnimationOptionCurveLinear animations:^{
            label.alpha = 0;
        }                completion:^(BOOL finished) {
            [label removeFromSuperview];
        }];
    }
}

- (void)tapGesture:(UIGestureRecognizer *)recognizer {
    CGPoint touchPoint = [recognizer locationInView:self.rootViewController.view];
    UIView *target = [self findTarget:touchPoint];

    if (!target && selectedView) {
        [self deactivateTarget];
    } else if (target) {
        [self activateTarget:target];
    }
}

- (void)moveGesture:(UIGestureRecognizer *)recognizer {
    if (selectedView) {
        CGPoint touchPoint = [recognizer locationInView:self.rootViewController.view];

        if (recognizer.state == UIGestureRecognizerStateBegan) {
            startPoint = touchPoint;
            if (targetView) {
                // inside target
                if ([targetView shouldMove:touchPoint]) {
                    moving = YES;
                } else if ([targetView shouldResize:touchPoint]) {
                    moving = NO;
                }
            }
        }

        if (recognizer.state == UIGestureRecognizerStateChanged) {
            CGRect frame = selectedView.frame;
            if (moving) {
                CGPoint vector = CGPointMake(startPoint.x - touchPoint.x, startPoint.y - touchPoint.y);

                // move selectedview
                frame.origin.x -= vector.x;
                frame.origin.y -= vector.y;
            } else {
                // resize selected view
                CGPoint vector = CGPointMake(startPoint.x - touchPoint.x, startPoint.y - touchPoint.y);

                if (selectedView.center.x > touchPoint.x) {
                    frame.origin.x -= vector.x;
                    frame.size.width += vector.x;
                } else {
                    frame.size.width -= vector.x;
                }

                if (selectedView.center.y > touchPoint.y) {
                    frame.origin.y -= vector.y;
                    frame.size.height += vector.y;
                } else {
                    frame.size.height -= vector.y;
                }
            }

            selectedView.frame = frame;

            [menuView updateTargetInfo];
            [targetView setNeedsDisplay];
            startPoint = touchPoint;
        }
    }

}

- (void)longPressGesture:(UIGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (!menuView.superview) {
            CGRect rect = self.rootViewController.view.bounds;
            menuView.center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
            [self addSubview:menuView];
        } else {
            menuView.target = nil;
            [menuView removeFromSuperview];
        }
    }
}

- (void)receiveAction:(PGAction)action {
    CGRect frame = selectedView.frame;

    switch (action) {
        case PGMoveLeft:
            frame.origin.x -= 1;
            selectedView.frame = frame;
            break;
        case PGMoveRight:
            frame.origin.x += 1;
            selectedView.frame = frame;
            break;
        case PGMoveUp:
            frame.origin.y -= 1;
            selectedView.frame = frame;
            break;
        case PGMoveDown:
            frame.origin.y += 1;
            selectedView.frame = frame;
            break;
        case PGIncreaseWidth:
            frame.size.width += 1;
            selectedView.frame = frame;
            break;
        case PGDecreaseWidth:
            frame.size.width -= 1;
            selectedView.frame = frame;
            break;
        case PGIncreaseHeight:
            frame.size.height += 1;
            selectedView.frame = frame;
            break;
        case PGDecreaseHeight:
            frame.size.height -= 1;
            selectedView.frame = frame;
            break;
        case PGMoveLeftInViews:
            if (selectedIndex > 0) {
                [self activateTarget:[selectedView.superview.subviews objectAtIndex:selectedIndex - 1]];
            }
            break;
        case PGMoveRightInViews:
            if (selectedIndex < [selectedView.superview.subviews count] - 3) {
                // account for subviews added
                UIView *target = selectedView;
                NSUInteger index = selectedIndex + 1;
                [self deactivateTarget];
                [self activateTarget:[target.superview.subviews objectAtIndex:index]];
            }
            break;
        case PGMoveUpInViews:
            if (selectedView.superview) {
                [self activateTarget:selectedView.superview];
            }
            break;
        case PGMoveDownInViews:
            if ([selectedView.subviews count] > 0) {
                [self activateTarget:[selectedView.subviews objectAtIndex:0]];
            }
            break;
        case PGProperties:
        {
            NSMutableString *properties = [NSMutableString stringWithFormat:@"\n************* %@ : %d *************\n", selectedView.class, selectedView.tag];
            [properties appendFormat:@"frame:\nCGRectMake(%.0f, %.0f, %.0f, %.0f);\n", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height];

            NSLog(@"%@", properties);
            break;
        }
        default:
            break;
    }

    [menuView updateTargetInfo];
    [targetView setNeedsDisplay];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (locked || (CGRectContainsPoint(menuView.frame, [gestureRecognizer locationInView:self.rootViewController.view]))) {
        return NO;
    } else {
        return YES;
    }
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor yellowColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.userInteractionEnabled = YES;
        self.locked = YES;

        UIRotationGestureRecognizer *rotationGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotateGesture:)];
        [self addGestureRecognizer:rotationGesture];
        [rotationGesture release];

        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
        tapGesture.delegate = self;
        [self addGestureRecognizer:tapGesture];
        [tapGesture release];

        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveGesture:)];
        panGesture.delegate = self;
        [self addGestureRecognizer:panGesture];
        [panGesture release];

        UILongPressGestureRecognizer *longGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGesture:)];
        longGesture.delegate = self;
        [self addGestureRecognizer:longGesture];
        [longGesture release];
    }

    return self;
}

- (id)initWithFrame:(CGRect)frame locked:(BOOL)lock {
    self = [self initWithFrame:frame];
    if (self) {
        self.locked = lock;

        self.menuView = [[PGMenuView alloc] initWithFrame:CGRectZero];
        menuView.delegate = self;
    }

    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (locked) {
        return [super hitTest:point withEvent:event];
    } else {
        if (CGRectContainsPoint(menuView.frame, point)) {
            return [super hitTest:point withEvent:event];
        }
        // prevent subviews from receiving events
        return self;
    }
}

- (void)dealloc {
    [targetView release];
    [inputView release];
    [overlayView release];

    [super dealloc];
}

@end