//
//  ViewController.m
//  gif图
//
//  Created by 孙丽 on 15/7/27.
//  Copyright (c) 2015年 bmuyu. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIWebView *myWebView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
    
    
    
    NSData * data = [NSData dataWithContentsOfFile:@"/Users/alldk/Downloads/1105gif图/gif图/可爱.gif"];
    
    [self.myWebView loadData:data MIMEType:@"image/gif" textEncodingName:nil baseURL:nil];

    self.imageview_gif = [[UIImageView alloc]initWithFrame:CGRectMake(0, 300, 320, 300)];
    [self.imageview_gif setBackgroundColor:[UIColor grayColor]];
    
    [self.view addSubview:self.imageview_gif];
    [self create];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)create
{
    /*
     *path :    本地gif路径
     *NSLog:    /Users/niuzhe/Desktop/孙丽/课堂练习/课堂练习 牛哲教/day26/gif图/gif图/可爱.gif
     *data :    取得这个gif
     */
    NSString *path = [[NSBundle mainBundle] pathForResource:@"可爱" ofType:@"gif"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    /*
     *gifLoopCount  : 设置一个gif的循环属性 ,值为0
     *NSLog:
     *{
     *   LoopCount = 0;
     *}
     */
    NSDictionary *gifLoopCount = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt:0] , (NSString *)kCGImagePropertyGIFLoopCount,nil
                                  ];
    /*
     *创建gif属性,可以看到只有一个属性：
     *      因为要得到gif，就必须创建gif，而创建就要有属性，所以这里设置了一个无用的属性，无限循环。用于创建gif，并且不覆盖原属性
     *NSLog:
     *{
     *  "{GIF}" =     {
     *      LoopCount = 0;
     *  };
     *}
     */
    NSDictionary * gifProperties = [NSDictionary dictionaryWithObject:gifLoopCount forKey:(NSString *)kCGImagePropertyGIFDictionary] ;
    /*
     *根据属性 还有data 得到gif，并存在CGImageSourceRef中
     *NSLog:    <CGImageSource 0x8d58740 [0x243a4d8]>
     *CFDictionaryRef ，得到gif的真正属性.
     *NSLog:
     *{
     *    ColorModel = RGB;
     *    Depth = 8;//
     *    HasAlpha = 1;
     *    PixelHeight = 22;
     *    PixelWidth = 22;
     *    "{GIF}" =     {
     *        DelayTime = "0.1";
     *        UnclampedDelayTime = "0.1";
     *    };
     *}
     *为什么要保存原属性呢。因为我们需要gif的原始延迟时间
     */
    CGImageSourceRef gif = CGImageSourceCreateWithData((__bridge  CFDataRef)(data), (__bridge  CFDictionaryRef)gifProperties);
    CFDictionaryRef gifprops =(CGImageSourceCopyPropertiesAtIndex(gif,0,NULL));
    /*
     *count :  gif的张数
     *NSLog:
     *(NSInteger) count = 19
     */
    NSInteger count =CGImageSourceGetCount(gif);
    /*
     *delay:    得到原始延迟时间
     *NSLog
     *{
     *    DelayTime = "0.1";
     *    UnclampedDelayTime = "0.1";
     *}
     */
    CFDictionaryRef  gifDic = CFDictionaryGetValue(gifprops, kCGImagePropertyGIFDictionary);

    
    NSNumber * delay = CFDictionaryGetValue(gifDic, kCGImagePropertyGIFDelayTime);

    NSNumber * w = CFDictionaryGetValue(gifprops, @"PixelWidth");
    NSNumber * h =CFDictionaryGetValue(gifprops, @"PixelHeight");
    /*
     *记算播放完一次gif需要多长时间。imageview播放动画需要这个时间
     */
    NSTimeInterval totalDuration  = delay.doubleValue * count;
    CGFloat pixelWidth = w.intValue;
    CGFloat pixelHeight = h.intValue;
    
    /*
     *循环取得gif中的图片然后加到数组中。
     */
    NSMutableArray *images = [[NSMutableArray alloc] init];
    for(int index=0;index<count;index++)
    {
        CGImageRef ref = CGImageSourceCreateImageAtIndex(gif, index, nil);
        UIImage *img = [UIImage imageWithCGImage:ref];
        [images addObject:img];
        CFRelease(ref);
        
    }
    
    CFRelease(gifprops);
    CFRelease(gif);
    /*
     *记得释放
     */
    
    [_imageview_gif setBounds:CGRectMake(0, 0, pixelWidth, pixelHeight)];
    
    [_imageview_gif setAnimationImages:images];
    
    [_imageview_gif setAnimationDuration:totalDuration];
    
    [_imageview_gif startAnimating];
    
}
@end
