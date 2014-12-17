//
//  SmudgyWindow.h
//  SmudgeKit
//
//  Created by Hans Petter Eikemo on 29.09.14.
//  Copyright (c) 2014 Ideon. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * Category on UIWindow that adds a property allowing one to
 * enable/disable SmudgeKit at will
 */
@interface UIWindow (SmudgeKitProperties)
@property (nonatomic, getter=isSmudgeKitEnabled) BOOL enableSmudgeKit;
@end

/**
 * The SmudgyWindow class is a drop in replacement for UIWindow which
 * draws a visual representation of all touch events onto the screen.
 */
@interface SmudgyWindow : UIWindow

@end
