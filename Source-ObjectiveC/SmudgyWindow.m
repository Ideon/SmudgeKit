//
//  SmudgyWindow.m
//  SmudgeKit
//
//  Created by Hans Petter Eikemo on 29.09.14.
//  Copyright (c) 2014 Ideon. All rights reserved.
//

#import "SmudgyWindow.h"

static CGFloat layerRadius;
static CGFloat layerLineWidth;
static UIColor* layerFillColor;
static UIColor* layerStrokeColor;

static UIColor* shadowColor;
static CGFloat shadowOpacity;
static CGFloat shadowRadius;
static CGSize shadowOffset;

#pragma mark - Private SmudgeLayer implementation -

@interface SmudgeLayer : CAShapeLayer

///Called when the related event changes. Override to update internal state. Position is set automatically by the superlayer.
- (void)appear;

///Called after smudge creation when a touch begins. Override to customize appear animation.
- (void)disappear;

///Called after the related touch event ends or is cancelled. Override to customize disappear animation, the user must call removeFromSuperview on the instance.
- (void)updateWithTouch:(UITouch *)touch;

@end

@interface SmudgeLayer ()

@property CGPoint velocity;
@property CGPoint previousPosition;

@end

@implementation SmudgeLayer

- (instancetype)init
{
    if (self = [super init]) {
        self.velocity = CGPointZero;
        self.contentsScale = [UIScreen mainScreen].scale;

        [self refreshLayerLooks];
        [self refreshShadowLooks];
    }
    return self;
}

#pragma mark Customize Looks

- (void)refreshLayerLooks
{
    self.fillColor = layerFillColor.CGColor;
    self.strokeColor = layerStrokeColor.CGColor;
    self.lineWidth = layerLineWidth;
    
    self.path = CGPathCreateWithEllipseInRect(CGRectMake(-layerRadius, -layerRadius, layerRadius*2, layerRadius*2), NULL);
    self.shadowPath = self.path;
}

- (void)refreshShadowLooks
{
    self.shadowPath = self.path;
    self.shadowColor = shadowColor.CGColor;
    self.shadowOpacity = shadowOpacity;
    self.shadowRadius = shadowRadius;
    self.shadowOffset = shadowOffset;
}

#pragma mark Manage Touche
- (void)updateWithTouch:(UITouch *)touch
{
    if (touch.phase != UITouchPhaseBegan) {
        self.velocity = CGPointMake( (self.velocity.x + self.position.x - self.previousPosition.x) * 0.5 , (self.velocity.y + self.position.y - self.previousPosition.y) * 0.5 );
    }
    self.previousPosition = self.position;
}

- (void)appear
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    self.opacity = 0.0;
    self.transform = CATransform3DMakeScale(1.5, 1.5, 1);

    [CATransaction commit];

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.1];

    self.opacity = 1.0;
    self.transform = CATransform3DIdentity;

    [CATransaction commit];

}

- (void)disappear
{
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.2];

    __weak typeof(self) weakSelf = self;
    [CATransaction setCompletionBlock:^{
        [weakSelf removeFromSuperlayer];
    }];

    self.opacity = 0.0;
    self.transform = CATransform3DMakeScale(1.5, 1.5, 1);
    self.position = CGPointMake( self.position.x + self.velocity.x * 4.0 , self.position.y + self.velocity.y * 4.0 );

    [CATransaction commit];

}


@end


#pragma mark - Private SmudgeContainer implementation -

@interface SmudgeContainerLayer : CALayer

- (void)updateWithEvent:(UIEvent *)event;

@end

@interface SmudgeContainerLayer ()

@property (readonly,nonatomic) NSMutableDictionary *touchSmudgeTable;

@end

@implementation SmudgeContainerLayer

- (instancetype)init
{
    if (self = [super init]) {
        _touchSmudgeTable = @{}.mutableCopy;
    }
    return self;
}

- (void)updateWithEvent:(UIEvent *)event
{
    for (UITouch *touch in event.allTouches) {
        NSValue* touchKey = [NSValue valueWithNonretainedObject:touch];
        SmudgeLayer* smudgeLayer = self.touchSmudgeTable[touchKey];

        [CATransaction begin];
        [CATransaction setDisableActions:YES];

        if (!smudgeLayer) {
            smudgeLayer = [SmudgeLayer layer];
            self.touchSmudgeTable[touchKey] = smudgeLayer;
            [self addSublayer:smudgeLayer];
        }

        smudgeLayer.position = [touch locationInView:nil];
        [smudgeLayer updateWithTouch:touch];

        [CATransaction commit];

        switch (touch.phase) {
            case UITouchPhaseBegan:
                [smudgeLayer appear];
                break;
            case UITouchPhaseCancelled:
            case UITouchPhaseEnded:
                [smudgeLayer disappear];
                [self.touchSmudgeTable removeObjectForKey:touchKey];
                break;
            default:
                break;
        }

    }
}

#pragma mark Customize Looks

- (void)refreshLayerLooks
{
    for (SmudgeLayer* smudgeLayer in self.touchSmudgeTable)
    {
        [smudgeLayer refreshLayerLooks];
    }
}

- (void)refreshShadowLooks
{
    for (SmudgeLayer* smudgeLayer in self.touchSmudgeTable)
    {
        [smudgeLayer refreshShadowLooks];
    }
}

@end


#pragma mark - SmudgyWindow -

@interface SmudgyWindow ()

@property (readonly,nonatomic) SmudgeContainerLayer *smudgeContainer;

@end

@implementation SmudgyWindow

+ (void)initialize
{
    layerRadius = 20.0;
    layerFillColor = [UIColor colorWithWhite:0.9 alpha:0.9];
    layerStrokeColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    layerLineWidth = 1;
    
    shadowColor = [UIColor blackColor];
    shadowOpacity = 0.15;
    shadowRadius = 3.0;
    shadowOffset = CGSizeMake(0.0, 1.0);
}

- (void)sendEvent:(UIEvent *)event
{
    [super sendEvent:event];
    [self renderTouchesForEvent:event];
}

- (void)renderTouchesForEvent:(UIEvent *)event
{
    if (!self.smudgeContainer) {
        _smudgeContainer = [SmudgeContainerLayer layer];
        [self.layer addSublayer:self.smudgeContainer];
    } else if ([self.layer.sublayers lastObject] != self.smudgeContainer) {
	    [self.smudgeContainer removeFromSuperlayer];
	    [self.layer addSublayer:self.smudgeContainer];
    }
    [self.smudgeContainer updateWithEvent:event];
}

#pragma mark Customize Looks

- (void)updateLayerRadius:(CGFloat)newRadius
                lineWidth:(CGFloat)newLineWidth
                fillColor:(UIColor*)newFillColor
              strokeColor:(UIColor*)newStrokeColor
{
    if (newRadius > 0)
        layerRadius = newRadius;
    if (newLineWidth >= 0)
        layerLineWidth = newLineWidth;
    if (newFillColor)
        layerFillColor = newFillColor;
    if (newStrokeColor)
        layerStrokeColor = newStrokeColor;
    
    [self.smudgeContainer refreshLayerLooks];
}

- (void)updateShadowColor:(UIColor*)newShadowColor
             shadowRadius:(CGFloat)newShadowRadius
            shadowOpacity:(CGFloat)newShadowOpacity
             shadowOffset:(CGSize)newShadowOffset
{
    if (newShadowColor)
        shadowColor = newShadowColor;
    if (newShadowRadius >= 0)
        shadowRadius = newShadowRadius;
    if (newShadowOpacity >= 0 && newShadowOpacity <= 1)
        shadowOpacity = newShadowOpacity;
    
    shadowOffset = newShadowOffset;
    

    [self.smudgeContainer refreshShadowLooks];
}

@end
