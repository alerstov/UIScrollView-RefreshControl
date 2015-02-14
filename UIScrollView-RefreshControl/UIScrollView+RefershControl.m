//
//  UIScrollView+RefershControl.m
//  RefershControl
//
//  Created by Alexander Stepanov on 2/13/15.
//  Copyright (c) 2015 Alexander Stepanov. All rights reserved.
//

#import "UIScrollView+RefershControl.h"
#import <objc/runtime.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#define TRACE_ENABLED 0

#if TRACE_ENABLED
#   define TRACE(_format, ...) NSLog(_format, ##__VA_ARGS__)
#else
#   define TRACE(_format, ...)
#endif

// Default values
#define kDefaultNumberOfSpinnerMarkers 12
#define kDefaultSpread 10.0
#define kDefaultColor ([UIColor colorWithWhite:0.3 alpha:1.0])
#define kDefaultThickness 2.0
#define kDefaultLength 8.0
#define kDefaultSpeed 1.0
#define kDefaultHUDSide 60.0
#define kDefaultStartRefreshHeight 112.0
#define kDefaultEndAnimateHeight 10.0
#define kDefaultInstanceDeltaHeight 20.0
#define kDefaultMaxVelocity 3500.0


static const void *ScrollViewKey = &ScrollViewKey;


typedef NS_ENUM(NSInteger, SmoothRefreshControlState) {
    SmoothRefreshControlStateNone,
    SmoothRefreshControlStateAnimating,
    SmoothRefreshControlStateGoAway
};

static void swizzle(Class cls, SEL origSel, SEL swizSel)
{
    Method origMethod = class_getInstanceMethod(cls, origSel);
    Method swizMethod = class_getInstanceMethod(cls, swizSel);
    
    if (class_addMethod(cls, origSel, method_getImplementation(swizMethod), method_getTypeEncoding(swizMethod))){
        class_replaceMethod(cls, swizSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }
    else{
        method_exchangeImplementations(origMethod, swizMethod);
    }
}



#pragma mark -

@interface SmoothRefreshControl : UIView
@property (nonatomic, readonly) SmoothRefreshControlState state;
@property (nonatomic) CAReplicatorLayer* replicator;
@property (nonatomic) CAShapeLayer* marker;

// state props
@property (nonatomic) BOOL touching;
@property (nonatomic) BOOL refreshing;
@property (nonatomic) BOOL ignoreContentOffset;
@property (nonatomic, copy) void (^refreshBegan)(void);
@end


@interface UIPanGestureRecognizer (Swizzle)
@property (nonatomic, assign) UIScrollView* scrolView;
@end


@interface UIScrollView (PrivateRefershControl)
@property (nonatomic, readonly) SmoothRefreshControl* smoothRefreshControl;
-(void)onTouchesBegan;
-(void)onTouchesEnd;
@end



#pragma mark -

@implementation SmoothRefreshControl

-(void)setup
{
    self.clipsToBounds = YES;
    self.layer.transform = CATransform3DMakeRotation(M_PI, 0.0, 0.0, 1.0);
    
    // replicator
    self.replicator = [CAReplicatorLayer layer];
    self.replicator.frame = CGRectMake(0, 0, kDefaultHUDSide, kDefaultHUDSide);
    self.replicator.instanceCount = kDefaultNumberOfSpinnerMarkers;
    self.replicator.instanceDelay = kDefaultSpeed/kDefaultNumberOfSpinnerMarkers;
    CGFloat angle = (2.0*M_PI)/(kDefaultNumberOfSpinnerMarkers);
    self.replicator.instanceTransform = CATransform3DMakeRotation(angle, 0.0, 0.0, 1.0);
    [self.layer addSublayer:self.replicator];
    
    // marker
    self.marker = [CAShapeLayer layer];
    self.marker.bounds = CGRectMake(0, 0, kDefaultThickness, kDefaultLength);
    UIBezierPath* path = [UIBezierPath bezierPathWithRoundedRect:self.marker.bounds
                                                    cornerRadius:kDefaultThickness*0.5];
    self.marker.path = path.CGPath;
    self.marker.fillColor = [kDefaultColor CGColor];
    self.marker.position = CGPointMake(kDefaultHUDSide*0.5, kDefaultHUDSide*0.5+kDefaultSpread);
    [self.replicator addSublayer:self.marker];
}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (_state == SmoothRefreshControlStateNone){
        float ht = MAX(0, self.frame.size.height - kDefaultInstanceDeltaHeight);
        float k = ht/(kDefaultStartRefreshHeight - kDefaultInstanceDeltaHeight);
        self.replicator.timeOffset = MIN(1, k);
        self.replicator.speed = 0;
    }
    
    CATransform3D tr = CATransform3DIdentity;
    if (_state == SmoothRefreshControlStateGoAway){
        float scale = MIN(kDefaultHUDSide, self.frame.size.height) / kDefaultHUDSide;
        tr = CATransform3DMakeScale(scale, scale, 1.0);
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions: YES];
    self.replicator.transform = tr;
    self.replicator.position = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    [CATransaction commit];
}

-(void)beginAnimating:(float)velocity
{
    if (_state != SmoothRefreshControlStateNone) return;
    
    _state = SmoothRefreshControlStateAnimating;
    TRACE(@"begin animating");

    self.replicator.speed = 1;
    
    // marker
    CABasicAnimation * fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @1.0;
    fade.toValue = @0.0;
    fade.repeatCount = HUGE_VALF;
    fade.duration = kDefaultSpeed;
    [self.marker addAnimation:fade forKey:@"markerAnimation"];
    
    // rotation
    float k = MIN(kDefaultMaxVelocity, velocity)/kDefaultMaxVelocity;
    float c2x = 0.3*(1-k);

    CABasicAnimation* anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    anim.fromValue = @(0);
    anim.toValue = @(M_PI);
    anim.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.0 :0.0 :c2x :1.0];
    anim.duration = 3 - k*2;
    anim.removedOnCompletion = NO;
    anim.fillMode = kCAFillModeForwards;
    [self.replicator addAnimation:anim forKey:@"rotateAnimation"];
}

-(void)goAway
{
    if (_state != SmoothRefreshControlStateAnimating) return;
    
    _state = SmoothRefreshControlStateGoAway;
    TRACE(@"go away");
    
    CABasicAnimation* anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    anim.fromValue = @(0.0);
    anim.toValue = @(2*M_PI);
    anim.duration = 0.5;
    anim.repeatCount = HUGE_VALF;
    [self.replicator addAnimation:anim forKey:@"rotateAnimation"];
}

-(void)endAnimating
{
    if (_state == SmoothRefreshControlStateNone) return;
    
    _state = SmoothRefreshControlStateNone;
    TRACE(@"end animating");

    [self.replicator removeAllAnimations];
    [self.marker removeAllAnimations];
}

@end



#pragma mark -


@implementation UIPanGestureRecognizer (Swizzle)

+(void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzle([self class],  @selector(touchesBegan:withEvent:), @selector(my_touchesBegan:withEvent:));
        swizzle([self class],  @selector(setState:), @selector(my_setState:));
    });
}

-(UIScrollView *)scrolView
{
    return objc_getAssociatedObject(self, ScrollViewKey);
}

-(void)setScrolView:(UIScrollView *)scrolView
{
    objc_setAssociatedObject(self, ScrollViewKey, scrolView, OBJC_ASSOCIATION_ASSIGN);
}

-(void)my_touchesBegan:(NSSet *)set withEvent:(UIEvent *)event
{
    [self my_touchesBegan:set withEvent:event];
    [self.scrolView onTouchesBegan];
}

-(void)my_setState:(UIGestureRecognizerState)state
{
    [self my_setState:state];
    if (state == UIGestureRecognizerStateEnded ||
        state == UIGestureRecognizerStateFailed){
        [self.scrolView onTouchesEnd];
    }
}

@end



#pragma mark -

@implementation UIScrollView (RefershControl)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzle([self class], @selector(setContentOffset:), @selector(my_setContentOffset:));
    });
}

-(void)enableRefreshingWithHandler:(void (^)(void))handler
{
    SmoothRefreshControl* smoothRefreshControl = [[SmoothRefreshControl alloc]init];
    smoothRefreshControl.refreshBegan = handler;
    [smoothRefreshControl setup];
    
    [self insertSubview:smoothRefreshControl atIndex:0];
    self.panGestureRecognizer.scrolView = self;
}

-(BOOL)refreshing
{
    return self.smoothRefreshControl.refreshing;
}

-(void)endRefreshing
{
    if (!self.smoothRefreshControl.refreshing) return;
    
    self.smoothRefreshControl.refreshing = NO;
    TRACE(@"end refreshing");
    
    if (!self.smoothRefreshControl.touching){
        [self checkGoAway];
        [self popContentInset];
    }
    
    [self checkEndAnimating];
}


#pragma mark -

-(SmoothRefreshControl *)smoothRefreshControl
{
    id view = [self.subviews firstObject];
    return [view isKindOfClass:[SmoothRefreshControl class]] ? view : nil;
}

-(void)onTouchesBegan
{
    self.smoothRefreshControl.touching = YES;
    TRACE(@"begin touching");
    
    if (self.smoothRefreshControl.state == SmoothRefreshControlStateGoAway){
        [self.panGestureRecognizer setState:UIGestureRecognizerStateBegan];
    }
}

-(void)onTouchesEnd
{
    self.smoothRefreshControl.touching = NO;
    
    if (self.smoothRefreshControl != nil){
        TRACE(@"end touching");
        
        if (!self.smoothRefreshControl.refreshing){
            [self checkGoAway];
        }
        
        if (self.smoothRefreshControl.refreshing){
            [self pushContentInset];
        }else{
            [self popContentInset];
        }
    }
}

-(void)my_setContentOffset:(CGPoint)contentOffset
{
    [self my_setContentOffset:contentOffset];
    
    if (self.smoothRefreshControl != nil){
        if (!self.smoothRefreshControl.ignoreContentOffset){
            
            // frame
            float delta = self.contentOffset.y > 0 ? 0 : -self.contentOffset.y;
            self.smoothRefreshControl.frame = CGRectMake(0, -delta, self.frame.size.width, delta);
            
            if (!self.smoothRefreshControl.refreshing && !self.smoothRefreshControl.touching){
                [self checkGoAway];
            }

            if (!self.smoothRefreshControl.refreshing){
                if (self.smoothRefreshControl.state != SmoothRefreshControlStateNone){
                    [self checkEndAnimating];
                }else{
                    [self checkBeginAnimating];
                }
            }
        }
    }
}


#pragma mark -

-(void)checkGoAway
{
    if (self.contentOffset.y >= -kDefaultHUDSide){
        [self.smoothRefreshControl goAway];
    }
}

-(void)checkEndAnimating
{
    if (self.contentOffset.y > -kDefaultEndAnimateHeight){
        [self.smoothRefreshControl endAnimating];
    }
}

-(void)checkBeginAnimating
{
    if (self.contentOffset.y < -kDefaultStartRefreshHeight){
        
        self.smoothRefreshControl.refreshing = YES;
        TRACE(@"begin refreshing");

        float vel = [self.panGestureRecognizer velocityInView:self.superview].y;
        [self.smoothRefreshControl beginAnimating:vel];
        
        if (!self.smoothRefreshControl.touching){
            [self pushContentInset];
        }
        
        if (self.smoothRefreshControl.refreshBegan) self.smoothRefreshControl.refreshBegan();
    }
}

-(void)pushContentInset
{
    if (self.contentInset.top == 0){
        
        self.smoothRefreshControl.ignoreContentOffset = YES;
        CGPoint ofs = self.contentOffset;
        self.contentInset = UIEdgeInsetsMake(kDefaultHUDSide, 0, 0, 0);
        self.contentOffset = ofs;
        self.smoothRefreshControl.ignoreContentOffset = NO;
    }
}

-(void)popContentInset
{
    if (self.contentInset.top > 0){
        
        self.smoothRefreshControl.ignoreContentOffset = YES;
        CGPoint ofs = self.contentOffset;
        self.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        
        CGPoint ofs1 = self.contentOffset;
        self.contentOffset = ofs;
        self.smoothRefreshControl.ignoreContentOffset = NO;
        
        [self setContentOffset:ofs1 animated:YES];
    }
}

@end
