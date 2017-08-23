//
//  YLGIFImage.m
//  YLGIFImage
//
//  Created by Yong Li on 14-3-2.
//  Copyright (c) 2014年 Yong Li. All rights reserved.
//

#import "YLGIFImage.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <ImageIO/ImageIO.h>


//Define FLT_EPSILON because, reasons.
//Actually, I don't know why but it seems under certain circumstances it is not defined
#ifndef FLT_EPSILON
#define FLT_EPSILON __FLT_EPSILON__
#endif

inline static NSTimeInterval CGImageSourceGetGifFrameDelay(CGImageSourceRef imageSource, NSUInteger index)
{
    NSTimeInterval frameDuration = 0;
    CFDictionaryRef theImageProperties;
    if ((theImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, NULL))) {
        CFDictionaryRef gifProperties;
        if (CFDictionaryGetValueIfPresent(theImageProperties, kCGImagePropertyGIFDictionary, (const void **)&gifProperties)) {
            
            // lzy170823注：获取每帧图片的播放时长
            const void *frameDurationValue;
            // lzy170823注，获取kCGImagePropertyGIFUnclampedDelayTime
            if (CFDictionaryGetValueIfPresent(gifProperties, kCGImagePropertyGIFUnclampedDelayTime, &frameDurationValue)) {
                
                frameDuration = [(__bridge NSNumber *)frameDurationValue doubleValue];
                // lzy170823注：kCGImagePropertyGIFUnclampedDelayTime小于等于0，改为获取kCGImagePropertyGIFDelayTime
                if (frameDuration <= 0) {
                    if (CFDictionaryGetValueIfPresent(gifProperties, kCGImagePropertyGIFDelayTime, &frameDurationValue)) {
                        frameDuration = [(__bridge NSNumber *)frameDurationValue doubleValue];
                    }
                    
                    
                }
            }
        }
        CFRelease(theImageProperties);
    }
    
#ifndef OLExactGIFRepresentation
    //Implement as Browsers do.
    //See:  http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility
    //Also: http://blogs.msdn.com/b/ieinternals/archive/2010/06/08/animated-gifs-slow-down-to-under-20-frames-per-second.aspx
    // lzy170823注：再次处理frameDuration，处理逻辑和浏览器对这个情况的处理逻辑一样
    if (frameDuration < 0.02 - FLT_EPSILON) {
        frameDuration = 0.1;
    }
#endif
    return frameDuration;
}

/* lzy注170823
 判断一个CGImageSource是否包含gif数据。
 在- (id)initWithData:(NSData *)data scale:(CGFloat)scale方法中使用。
 重要判断之一也是UTTypeConformsTo
 */
inline static BOOL CGImageSourceContainsAnimatedGif(CGImageSourceRef imageSource)
{
    return imageSource && UTTypeConformsTo(CGImageSourceGetType(imageSource), kUTTypeGIF) && CGImageSourceGetCount(imageSource) > 1;
}

inline static BOOL isRetinaFilePath(NSString *path)
{
    NSRange retinaSuffixRange = [[path lastPathComponent] rangeOfString:@"@2x" options:NSCaseInsensitiveSearch];
    return retinaSuffixRange.length && retinaSuffixRange.location != NSNotFound;
}

@interface YLGIFImage ()

@property (nonatomic, readwrite) NSMutableArray *images;
@property (nonatomic, readwrite) NSTimeInterval *frameDurations;
@property (nonatomic, readwrite) NSTimeInterval totalDuration;
@property (nonatomic, readwrite) NSUInteger loopCount;
@property (nonatomic, readwrite) CGImageSourceRef incrementalSource;

@end

static NSUInteger _prefetchedNum = 10;

@implementation YLGIFImage
{
    dispatch_queue_t readFrameQueue;
    CGImageSourceRef _imageSourceRef;
    CGFloat _scale;
}

@synthesize images;

#pragma mark - Class Methods
/* lzy注170823
 override UIImage:原本的方法有app层级的全局的内存缓存，这样重写后这个方法没有了。
 内部使用imageWithContentsOfFile
 */
+ (id)imageNamed:(NSString *)name
{
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:nil];
    
    return ([[NSFileManager defaultManager] fileExistsAtPath:path]) ? [self imageWithContentsOfFile:path] : nil;
}
/* lzy注170823
 override UIImage。加入了对传入图片地址最后是否加载高清图片的判断。isRetinaFilePath是一个判断path字符串含有@2x这个字符串的结果
 */
+ (id)imageWithContentsOfFile:(NSString *)path
{
    return [self imageWithData:[NSData dataWithContentsOfFile:path]
                         scale:isRetinaFilePath(path) ? 2.0f : 1.0f];
}
/* lzy注170823
 override UIImage
 */
+ (id)imageWithData:(NSData *)data
{
    return [self imageWithData:data scale:1.0f];
}
/* lzy注170823
 override UIImage
 */
+ (id)imageWithData:(NSData *)data scale:(CGFloat)scale
{
    if (!data) {
        return nil;
    }
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)(data), NULL);
    UIImage *image;
    
    if (CGImageSourceContainsAnimatedGif(imageSource)) {
        image = [[self alloc] initWithCGImageSource:imageSource scale:scale];// lzy170823注：这句代码是关键点
    } else {
        image = [super imageWithData:data scale:scale];
    }
    
    if (imageSource) {
        CFRelease(imageSource);
    }
    
    return image;
}

#pragma mark - Initialization methods
// lzy170823注：override UIImage
- (id)initWithContentsOfFile:(NSString *)path
{
    return [self initWithData:[NSData dataWithContentsOfFile:path]
                        scale:isRetinaFilePath(path) ? 2.0f : 1.0f];
}
// lzy170823注：override UIImage
- (id)initWithData:(NSData *)data
{
    return [self initWithData:data scale:1.0f];
}
// lzy170823注：override UIImage
- (id)initWithData:(NSData *)data scale:(CGFloat)scale
{
    if (!data) {
        return nil;
    }
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)(data), NULL);
    // 内联函数判断
    if (CGImageSourceContainsAnimatedGif(imageSource)) {
        self = [self initWithCGImageSource:imageSource scale:scale];// 关键点
    } else {
        if (scale == 1.0f) {
            self = [super initWithData:data];
        } else {
            self = [super initWithData:data scale:scale];
        }
    }
    
    if (imageSource) {
        CFRelease(imageSource);
    }
    
    return self;
}

/* lzy注170823，关键方法
 
 */
- (id)initWithCGImageSource:(CGImageSourceRef)imageSource scale:(CGFloat)scale
{
    self = [super init];
    if (!imageSource || !self) {
        return nil;
    }
    
    CFRetain(imageSource);
    
    NSUInteger numberOfFrames = CGImageSourceGetCount(imageSource);
    
    NSDictionary *imageProperties = CFBridgingRelease(CGImageSourceCopyProperties(imageSource, NULL));
    NSDictionary *gifProperties = [imageProperties objectForKey:(NSString *)kCGImagePropertyGIFDictionary];
    
    self.frameDurations = (NSTimeInterval *)malloc(numberOfFrames  * sizeof(NSTimeInterval));
    self.loopCount = [gifProperties[(NSString *)kCGImagePropertyGIFLoopCount] unsignedIntegerValue];
    // 创建一个可变数组，元素容量是gif图片的帧数
    self.images = [NSMutableArray arrayWithCapacity:numberOfFrames];
    
    NSNull *aNull = [NSNull null];
    for (NSUInteger i = 0; i < numberOfFrames; ++i) {
        [self.images addObject:aNull];
        
        // lzy170823注：内联函数，在本类最上边，返回一帧图片的播放时间
        NSTimeInterval frameDuration = CGImageSourceGetGifFrameDelay(imageSource, i);
        
        self.frameDurations[i] = frameDuration;
        self.totalDuration += frameDuration;
    }
    // CFTimeInterval start = CFAbsoluteTimeGetCurrent();
    // Load first frame
    NSUInteger num = MIN(_prefetchedNum, numberOfFrames);// 大于10帧，先读10帧
    for (NSUInteger i=0; i<num; i++) {
        // 创建一帧图片
        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, i, NULL);
        if (image != NULL) {
            /* lzy注170823
             // [UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp]是原生方法。
             创建的一帧图片成功，用它替换之前numberOfFrames大小的全是null对象的images数组，在该索引元素。
             在蓝懿3、4月的百度云中有一个非常简化的版本：1105gif图
             可以参考。
             */
            [self.images replaceObjectAtIndex:i withObject:[UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp]];
            CFRelease(image);
        } else {
            [self.images replaceObjectAtIndex:i withObject:[NSNull null]];
        }
    }
    _imageSourceRef = imageSource;
    CFRetain(_imageSourceRef);
    CFRelease(imageSource);
    //});
    
    _scale = scale;
    readFrameQueue = dispatch_queue_create("com.ronnie.gifreadframe", DISPATCH_QUEUE_SERIAL);
    
    return self;
}
/* lzy注170823：自定义方法。
 依旧还是两步走：
1、 CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSourceRef, _idx, NULL);
2、 [self.images replaceObjectAtIndex:_idx withObject:[UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp]];
 
 条件判断多了很多考虑，
 self.images访问加了锁


 */
- (UIImage*)getFrameWithIndex:(NSUInteger)idx
{
    //    if([self.images[idx] isKindOfClass:[NSNull class]])
    //        return nil;
    UIImage* frame = nil;
    @synchronized(self.images) {
        frame = self.images[idx];
    }
    if(!frame) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSourceRef, idx, NULL);
        if (image != NULL) {
            frame = [UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp];
            CFRelease(image);
        }
    }
    if(self.images.count > _prefetchedNum) {
        if(idx != 0) {
            [self.images replaceObjectAtIndex:idx withObject:[NSNull null]];
        }
        NSUInteger nextReadIdx = (idx + _prefetchedNum);
        for(NSUInteger i=idx+1; i<=nextReadIdx; i++) {
            NSUInteger _idx = i%self.images.count;
            if([self.images[_idx] isKindOfClass:[NSNull class]]) {
                dispatch_async(readFrameQueue, ^{
                    CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSourceRef, _idx, NULL);
                    @synchronized(self.images) {
                        if (image != NULL) {
                            [self.images replaceObjectAtIndex:_idx withObject:[UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp]];
                            CFRelease(image);
                        } else {
                            [self.images replaceObjectAtIndex:_idx withObject:[NSNull null]];
                        }
                    }
                });
            }
        }
    }
    return frame;
}

#pragma mark - Compatibility methods

- (CGSize)size
{
    if (self.images.count) {
        return [[self.images objectAtIndex:0] size];
    }
    return [super size];
}

- (CGImageRef)CGImage
{
    if (self.images.count) {
        return [[self.images objectAtIndex:0] CGImage];
    } else {
        return [super CGImage];
    }
}

- (UIImageOrientation)imageOrientation
{
    if (self.images.count) {
        return [[self.images objectAtIndex:0] imageOrientation];
    } else {
        return [super imageOrientation];
    }
}

- (CGFloat)scale
{
    if (self.images.count) {
        return [(UIImage *)[self.images objectAtIndex:0] scale];
    } else {
        return [super scale];
    }
}

- (NSTimeInterval)duration
{
    return self.images ? self.totalDuration : [super duration];
}

- (void)dealloc {
    if(_imageSourceRef) {
        CFRelease(_imageSourceRef);
    }
    free(_frameDurations);
    if (_incrementalSource) {
        CFRelease(_incrementalSource);
    }
}

@end
