//
//  YLImageView.m
//  YLGIFImage
//
//  Created by Yong Li on 14-3-2.
//  Copyright (c) 2014年 Yong Li. All rights reserved.
//

#import "YLImageView.h"
#import "YLGIFImage.h"
#import <QuartzCore/QuartzCore.h>

@interface YLImageView ()

@property (nonatomic, strong) YLGIFImage *animatedImage;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic) NSTimeInterval accumulator;
@property (nonatomic) NSUInteger currentFrameIndex;
@property (nonatomic, strong) UIImage* currentFrame;
@property (nonatomic) NSUInteger loopCountdown;

@end

@implementation YLImageView

const NSTimeInterval kMaxTimeStep = 1; // note: To avoid spiral-o-death

@synthesize runLoopMode = _runLoopMode;
@synthesize displayLink = _displayLink;

- (id)init
{
    self = [super init];
    if (self) {
        /* lzy注170823
         // 初始化为0
         */
        self.currentFrameIndex = 0;
    }
    return self;
}

- (CADisplayLink *)displayLink
{/* lzy注170823
  // 本来调用时机就是特定的时间点，不仅调用时机会注意，懒加载中本身还要对时机进行过滤
  */

    if (self.superview) {
        // 有父视图的情况下
        if (!_displayLink && self.animatedImage) {
            _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(changeKeyframe:)];
            [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:self.runLoopMode];
        }
    } else {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    return _displayLink;
}

- (NSString *)runLoopMode
{
    return _runLoopMode ?: NSRunLoopCommonModes;
}

- (void)setRunLoopMode:(NSString *)runLoopMode
{/* lzy注170823
  // setter方法中，根据传入的值，做一些操作，这也是重写setter方法的意义所在。
  */
    if (runLoopMode != _runLoopMode) {
        [self stopAnimating];
        
        NSRunLoop *runloop = [NSRunLoop mainRunLoop];
        [self.displayLink removeFromRunLoop:runloop forMode:_runLoopMode];
        [self.displayLink addToRunLoop:runloop forMode:runLoopMode];
        
        _runLoopMode = runLoopMode;
        
        [self startAnimating];
    }
}

/* lzy注170823
 // override。这个方法是可以解释，在TuiaCopy工程里，把正常使用UIImageView+AFN，在返回数据序列化的时候，判断文件头为gif，使用YLGIFImage根据data创建image对象，到了UIImageView+AFN 148行回调中，直接                               strongSelf.image = responseObject;会自动播放gif。实际上是调用self.animatedImage = (YLGIFImage *)image;
 */
- (void)setImage:(UIImage *)image
{
    if (image == self.image) {
        return;
    }
    
    [self stopAnimating];
    
    self.currentFrameIndex = 0;
    self.loopCountdown = 0;
    self.accumulator = 0;
    
    if ([image isKindOfClass:[YLGIFImage class]] && image.images) {
        // 传入是gif，是多个图片的集合
        
        if([image.images[0] isKindOfClass:UIImage.class])// 使用了isKindOfClass来区分UIImage和YLGIFImage对象
            [super setImage:image.images[0]];
        else
            [super setImage:nil];
        self.currentFrame = nil;
        self.animatedImage = (YLGIFImage *)image;// 这句代码是关键点
        self.loopCountdown = self.animatedImage.loopCount ?: NSUIntegerMax;
        [self startAnimating];
    } else {
        // 传入的是一张普通图
        self.animatedImage = nil;
        [super setImage:image];
    }
    // 刷新
    [self.layer setNeedsDisplay];
}
// override UIImageView
- (void)setAnimatedImage:(YLGIFImage *)animatedImage
{
    _animatedImage = animatedImage;
    if (animatedImage == nil) {
        self.layer.contents = nil;
    }
}
// override UIImageView
- (BOOL)isAnimating
{
    return [super isAnimating] || (self.displayLink && !self.displayLink.isPaused);
}

// override UIImageView
- (void)stopAnimating
{
    if (!self.animatedImage) {
        [super stopAnimating];
        return;
    }
    
    self.loopCountdown = 0;
    
    self.displayLink.paused = YES;
}
// override UIImageView
- (void)startAnimating
{
    if (!self.animatedImage) {
        [super startAnimating];
        return;
    }
    
    if (self.isAnimating) {
        return;
    }
    
    self.loopCountdown = self.animatedImage.loopCount ?: NSUIntegerMax;
    
    self.displayLink.paused = NO;
}
/* lzy注170823
 这是displayLink不断触发的调用方法
 */
- (void)changeKeyframe:(CADisplayLink *)displayLink
{
    if (self.currentFrameIndex >= [self.animatedImage.images count]) {
        return;
    }
    self.accumulator += fmin(displayLink.duration, kMaxTimeStep);
    
    while (self.accumulator >= self.animatedImage.frameDurations[self.currentFrameIndex]) {
        self.accumulator -= self.animatedImage.frameDurations[self.currentFrameIndex];
        if (++self.currentFrameIndex >= [self.animatedImage.images count]) {
            if (--self.loopCountdown == 0) {
                [self stopAnimating];
                return;
            }
            self.currentFrameIndex = 0;
        }
        self.currentFrameIndex = MIN(self.currentFrameIndex, [self.animatedImage.images count] - 1);
        // lzy170823注：这个方法的关键点。不断改变当前显示的图片，即self.currentFrame
        
        self.currentFrame = [self.animatedImage getFrameWithIndex:self.currentFrameIndex];
        /* lzy注170823,layer的重绘
         Marks the receiver’s entire bounds rectangle as needing to be redrawn.
         You can use this method or the setNeedsDisplayInRect: to notify the system that your view’s contents need to be redrawn. This method makes a note of the request and returns immediately. The view is not actually redrawn until the next drawing cycle, at which point all invalidated views are updated.
         Note
         If your view is backed by a CAEAGLLayer object, this method has no effect. It is intended for use only with views that use native drawing technologies (such as UIKit and Core Graphics) to render their content.
         You should use this method to request that a view be redrawn only when the content or appearance of the view change. If you simply change the geometry of the view, the view is typically not redrawn. Instead, its existing content is adjusted based on the value in the view’s contentMode property. Redisplaying the existing content improves performance by avoiding the need to redraw content that has not changed.
         Availability	iOS (2.0 and later), tvOS (9.0 and later)
         */
        [self.layer setNeedsDisplay];
    }
}

/* lzy注170823。
 
 时间到了（CADisplayLink），触发上面那个方法，获取到当前的self.currentFrame（图片），调用了[self.layer setNeedsDisplay];
 立即会来到这个方法，然后设置layer.contents = (__bridge id)([self.currentFrame CGImage]);
 
 CALayerDelegate中方法。
 
 - (void)displayLayer:(CALayer *)layer;
 Description  Tells the delegate to implement the display process.
 The displayLayer: delegate method is invoked when the layer is marked for its content to be reloaded, typically initiated by the setNeedsDisplay method. 
 
 The typical technique for updating is to set the layer's contents property.
 Parameters layer  The layer whose contents need updating.
 Availability	iOS (10.0 and later), macOS (10.12 and later), tvOS (10.0 and later)
 奇怪了，在模拟器8.1也可以使用，且会调用这个方法
 */
- (void)displayLayer:(CALayer *)layer
{
    if (!self.animatedImage || [self.animatedImage.images count] == 0) {
        return;
    }
    //NSLog(@"display index: %luu", (unsigned long)self.currentFrameIndex);
    if(self.currentFrame && ![self.currentFrame isKindOfClass:[NSNull class]])
        layer.contents = (__bridge id)([self.currentFrame CGImage]);
}

// override UIView
- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self startAnimating];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.window) {
                [self stopAnimating];
            }
        });
    }
}
// override UIView
- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    if (self.superview) {
        //Has a superview, make sure it has a displayLink
        [self displayLink];
    } else {
        //Doesn't have superview, let's check later if we need to remove the displayLink
        dispatch_async(dispatch_get_main_queue(), ^{
            [self displayLink];
        });
    }
}
// override UIImageView
- (void)setHighlighted:(BOOL)highlighted
{
    if (!self.animatedImage) {
        [super setHighlighted:highlighted];
    }
}

// override UIImageView
- (UIImage *)image
{
    return self.animatedImage ?: [super image];
}

// override UIView
- (CGSize)sizeThatFits:(CGSize)size
{
    return self.image.size;
}

@end

