//
//  SeMonitorController.m
//  RunloopMonitorDemo
//
//  Created by game3108 on 16/4/14.
//  Copyright © 2016年 game3108. All rights reserved.
//

#import "SeMonitorController.h"
#import <libkern/OSAtomic.h>
#import <execinfo.h>

@interface SeMonitorController(){
    CFRunLoopObserverRef _observer;
    dispatch_semaphore_t _semaphore;
    CFRunLoopActivity _activity;
    NSInteger _countTime;
    NSMutableArray *_backtrace;
}

@end

@implementation SeMonitorController

+ (instancetype) sharedInstance{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void) startMonitor{
    _backtrace=[[NSMutableArray alloc]init];
    [self registerObserver];
}

- (void) endMonitor{
    if (!_observer) {
        return;
    }
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    CFRelease(_observer);
    _observer = NULL;
}

- (void) printLogTrace{
    if(_backtrace==NULL)
        NSLog(@"======未检出卡顿========\n");
    else
    {
        NSLog(@"======堆栈======= \n");
        for(NSMutableArray *temp in _backtrace)
        {
            NSLog(@"%@",temp);
        }
    }
}

static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    SeMonitorController *instrance = [SeMonitorController sharedInstance];
    instrance->_activity = activity;
    // 发送信号
    dispatch_semaphore_t semaphore = instrance->_semaphore;
    dispatch_semaphore_signal(semaphore);
}

- (void)registerObserver
{
    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL};
    _observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                                            kCFRunLoopAllActivities,
                                                            YES,
                                                            0,
                                                            &runLoopObserverCallBack,
                                                            &context);
    CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    
    // 创建信号
    _semaphore = dispatch_semaphore_create(0);
    
    // 在子线程监控时长
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (YES)
        {
            // 假定连续5次超时50ms认为卡顿(当然也包含了单次超时250ms)
            long st = dispatch_semaphore_wait(_semaphore, dispatch_time(DISPATCH_TIME_NOW, 50*NSEC_PER_MSEC));
            if (st != 0)
            {
                if (_activity==kCFRunLoopBeforeSources || _activity==kCFRunLoopAfterWaiting)
                {
                    if (++_countTime < 5)
                        continue;
                    [self logStack];
                    NSLog(@"something log");
                }
            }
            _countTime = 0;
        }
    });
}

- (void)logStack{
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    int i;
    NSMutableArray *backtrace = [SeMonitorController sharedInstance]->_backtrace;
    NSMutableArray *temp=[NSMutableArray arrayWithCapacity:frames];
    for ( i = 0 ; i < frames ; i++ ){
        [temp addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    [backtrace addObject:temp];
    free(strs);
}

@end
