//
//  YLGIFImage.h
//  YLGIFImage
//
//  Created by Yong Li on 14-3-2.
//  Copyright (c) 2014年 Yong Li. All rights reserved.
//
/* lzy注170823
 一般使用：
 一、
 YLImageView* imageView = [[YLImageView alloc] initWithFrame:CGRectMake(0, 160, self.view.frame.size.width, 0.75*self.view.frame.size.width)];
 [self.view addSubview:imageView];
 imageView.image = [YLGIFImage imageNamed:@"joy.gif"];
 
 二、
 YLImageView* imageView = [[YLImageView alloc] initWithFrame:CGRectMake(0, 160, self.view.frame.size.width, 0.75*self.view.frame.size.width)];
 [self.view addSubview:imageView];
 // responseObject 是网络请求返回的一个gif的二进制数据
 imageView.image = [[YLGIFImage alloc] initWithData:responseObject];

 因为先看了FLAnimatedImage，将和这个类库对比起来看。
 */

#import <UIKit/UIKit.h>

@interface YLGIFImage : UIImage

///-----------------------
/// @name Image Attributes
///-----------------------
/* lzy注170823
 一个C 数组，内部包含着每一帧图片的播放时间。
 gif图片有多少帧是由images数组属性count定义的
 */
/**
 A C array containing the frame durations.
 
 The number of frames is defined by the count of the `images` array property.
 */
@property (nonatomic, readonly) NSTimeInterval *frameDurations;

/* lzy注170823
 一个gif从头播放到结束的时长
 */
/**
 Total duration of the animated image.
 */
@property (nonatomic, readonly) NSTimeInterval totalDuration;

/**
 Number of loops the image can do before it stops
 */
@property (nonatomic, readonly) NSUInteger loopCount;

- (UIImage*)getFrameWithIndex:(NSUInteger)idx;

@end
