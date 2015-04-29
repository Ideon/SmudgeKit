//
//  SmudgyWindow.h
//  SmudgeKit
//
//  Created by Hans Petter Eikemo on 29.09.14.
//  Copyright (c) 2014 Ideon. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * The SmudgyWindow class is a drop in replacement for UIWindow which
 * draws a visual representation of all touch events onto the screen.
 */
@interface SmudgyWindow : UIWindow

/**
 *  Customize the way the visual representations are displayed on screen
 *  @param newRadius      Size of the visual representation
 *  @param newLineWidth   Width of the border line of the visual representation
 *  @param newFillColor   Color of the visual representation body
 *  @param newStrokeColor Color of the border line of the visual representation body
 */
- (void)updateLayerRadius:(CGFloat)newRadius
                lineWidth:(CGFloat)newLineWidth
                fillColor:(UIColor*)newFillColor
              strokeColor:(UIColor*)newStrokeColor;

/**
 *  Customize the shadow of the visual representations
 *  @param newShadowColor   Color of the visual representation's shadow
 *  @param newShadowRadius  Spread radius of the visual representations's shadow
 *  @param newShadowOpacity Opacity of the visual representations's shadow
 *  @param newShadowOffset  Offset of the visual representations's shadow
 */
- (void)updateShadowColor:(UIColor*)newShadowColor
             shadowRadius:(CGFloat)newShadowRadius
            shadowOpacity:(CGFloat)newShadowOpacity
             shadowOffset:(CGSize)newShadowOffset;

@end
