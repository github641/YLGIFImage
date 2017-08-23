//
//  YLImageView.h
//  YLGIFImage
//
//  Created by Yong Li on 14-3-2.
//  Copyright (c) 2014年 Yong Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface YLImageView : UIImageView
/* lzy注170823
 可以说YLGIFImage是FLAnimatedImage简化版本易用版本。FLAnimatedImage中做了更多更全面的考虑。
 
 对比FLAnimatedImageView，它多暴露了较多的api，如当前帧的图片、当前帧的索引；播放循环的回调，和FLAnimatedImage对象等等。
 当然也包括runLoopMode,且说明了使用方法和默认值。
 
 这里默认的是NSRunLoopCommonModes
 */
@property (nonatomic, copy) NSString *runLoopMode;

@end
