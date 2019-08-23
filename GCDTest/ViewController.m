//
//  ViewController.m
//  GCDTest
//
//  Created by unakayou on 3/28/19.
//  Copyright © 2019 unakayou. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self test3];
}

//测试何时死锁
- (void)test1
{
    //执行顺序6、1、2、3、4、5 或 1、6、2、3、4、5
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"1.全局队列 - 异步执行block %@",[NSThread currentThread]);
        
        dispatch_async(dispatch_queue_create("this", DISPATCH_QUEUE_CONCURRENT), ^{
            NSLog(@"2.新建并发队列 - 异步执行block %@",[NSThread currentThread]);
        });
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"3.主队列 - 同步执行block %@ - %lf",[NSThread currentThread],[NSThread currentThread].threadPriority);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
                    NSLog(@"4.主线程 - 全局队列 - 同步执行block %@",[NSThread currentThread]);
                });
                
                NSLog(@"5.主队列 - 异步执行block %@",[NSThread currentThread]);
            });
        });
        
        dispatch_queue_t serialQueue = dispatch_queue_create("serialQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_async(serialQueue, ^{
            NSLog(@"6.新建串行队列 - 异步执行block %@",[NSThread currentThread]);
            //            dispatch_sync(serialQueue, ^{
            //                NSLog(@"7.新建串行队列 - 同步执行block %@",[NSThread currentThread]);
            //            });
        });
    });
    
    NSLog(@"8.外部 %@ - %lf",[NSThread currentThread],[NSThread currentThread].threadPriority);
}

//测试同步串行队列
//结论:主线程因为dispatch_sync阻塞，并且往一个新建的串行队列里添加block任务。添加完毕，dispatch_sync继续阻塞主线程，等待block返回，再执行下面的dispatch_sync block(2)
- (void)test2
{
    dispatch_queue_t queue = dispatch_queue_create("test", DISPATCH_QUEUE_CONCURRENT);
    dispatch_sync(queue, ^{
        for (int i = 0; i < 3; i++)
        {
            NSLog(@"并发同步1   %@",[NSThread currentThread]);
        }
    });
    dispatch_sync(queue, ^{
        for (int i = 0; i < 3; i++)
        {
            NSLog(@"并发同步2   %@",[NSThread currentThread]);
        }
    });
    dispatch_sync(queue, ^{
        for (int i = 0; i < 3; i++)
        {
            NSLog(@"并发同步3   %@",[NSThread currentThread]);
        }
    });
    NSLog(@"结束");
}

//栅栏方法测试异步并发读取 同步写
- (void)test3
{
    dispatch_queue_t concurrentQueue = dispatch_queue_create("concurrentQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(concurrentQueue, ^{
        for (int i = 0; i < 3; i++)
        {
            NSLog(@"异步读取 1   %@",[NSThread currentThread]);
        }
    });

    dispatch_async(concurrentQueue, ^{
        for (int i = 0; i < 3; i++)
        {
            NSLog(@"异步读取 2   %@",[NSThread currentThread]);
        }
    });
    
    //dispatch_barrier_sync:  等待栅栏block里面的代码运行完毕再将后面的3、4、5 block插入到queue中，然后开始执行后添加进去的block。
    //dispatch_barrier_async: 不等待栅栏block里面的代码运行完毕，继续向后执行，把block插入到queue中。等待栅栏前任务和栅栏任务执行完毕，再执行已经添加到队列里的3、4、5
    //所以，dispatch_barrier_async的不阻塞当前线程,dispatch_barrier_sync阻塞。
    dispatch_barrier_async(concurrentQueue, ^{
        NSLog(@"栅栏函数 -----------  %@",[NSThread currentThread]);
        
        dispatch_queue_t concurrentQueue2 = dispatch_queue_create("concurrentQueue2", DISPATCH_QUEUE_CONCURRENT);

        dispatch_sync(concurrentQueue2, ^{
            for (int i = 0; i < 3; i++)
            {
                NSLog(@"同步写入 3 - %@",[NSThread currentThread]);
            }
        });
        dispatch_sync(concurrentQueue2, ^{
            for (int i = 0; i < 3; i++)
            {
                NSLog(@"同步写入 4 - %@",[NSThread currentThread]);
            }
        });
        dispatch_sync(concurrentQueue2, ^{
            for (int i = 0; i < 3; i++)
            {
                NSLog(@"同步写入 5 - %@",[NSThread currentThread]);
            }
        });
        NSLog(@"栅栏函数 完毕 -----------  %@",[NSThread currentThread]);
    });

    dispatch_async(concurrentQueue, ^{
        for (int i = 0; i < 3; i++)
        {
            NSLog(@"异步读取 6   %@",[NSThread currentThread]);
        }
    });
    
    dispatch_async(concurrentQueue, ^{
        for (int i = 0; i < 3; i++)
        {
            NSLog(@"异步读取 7   %@",[NSThread currentThread]);
        }
    });
    
    dispatch_async(concurrentQueue, ^{
        for (int i = 0; i < 3; i++)
        {
            NSLog(@"异步读取 8   %@",[NSThread currentThread]);
        }
    });
}

//GCD队列组 (group可以管理多个queue)
- (void)testGroup
{
    dispatch_group_t group = dispatch_group_create();
//    dispatch_queue_t queue = dispatch_queue_create("groupSerialQueue", DISPATCH_QUEUE_SERIAL);          //开启一个新线程顺序执行
    dispatch_queue_t queue = dispatch_queue_create("groupConcurrentQueue", DISPATCH_QUEUE_CONCURRENT);  //开启多个新线程乱序执行
    dispatch_queue_t queue2 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);            //再创建一个队列,加入到group中管理
    
    //使用dispatch_async + 手动出入组,实现dispatch_group_async功能。enter leave必须成对出现,否则最后不会接到任务完成通知。
    dispatch_group_enter(group);
    dispatch_async(queue, ^{
        sleep(1);
        NSLog(@"队列组1: 有一个耗时操作完成！1 - %@",[NSThread currentThread]);
        dispatch_group_leave(group);
    });
    
    dispatch_group_async(group, queue2, ^{
        sleep(3);
        NSLog(@"队列组2: 有一个耗时操作完成！2 - %@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, queue, ^{
        NSLog(@"队列组1: 有一个耗时操作完成！3 - %@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, queue, ^{
        NSLog(@"队列组1: 有一个耗时操作完成！4 - %@",[NSThread currentThread]);
    });
    
    //dispatch_group_wait 会阻塞他的线程 等待超时或者group执行完,然后回调
    dispatch_async(queue, ^{
        long timeOut = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        if (timeOut)
        {
            NSLog(@"超时 - %@", [NSThread currentThread]);
        }
        else
        {
            NSLog(@"未超时 - %@",[NSThread currentThread]);
            
            dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                NSLog(@"notify - Refresh UI - %@",[NSThread currentThread]);
                
                //notify嵌套
                dispatch_group_async(group, queue, ^{
                    NSLog(@"notify - 队列组1: 有一个耗时操作完成! 5 - %@",[NSThread currentThread]);
                    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                        NSLog(@"notify - notify - Refresh UI - %@",[NSThread currentThread]);
                    });
                });
            });
        }
    });
}

//group + 信号量,防止dispatch_group_notify()提示执行完毕后,某个block里有耗时操作还未执行完毕
//也可以用dispatch_group_enter + dispatch_group_leaves实现
- (void)testGroup2
{
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create("groupConcurrentQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t queue2 = dispatch_queue_create("groupConcurrentQueue2", DISPATCH_QUEUE_CONCURRENT);

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_group_async(group, queue, ^{
        NSLog(@"task 1 begin : %@",[NSThread currentThread]);
        dispatch_async(queue2, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), queue, ^{
                NSLog(@"task 1 finish : %@",[NSThread currentThread]);
                dispatch_semaphore_signal(sema);
            });
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    });

    dispatch_group_async(group, queue, ^{
        NSLog(@"task 2 begin : %@",[NSThread currentThread]);
        dispatch_async(queue2, ^{
            NSLog(@"task 2 finish : %@",[NSThread currentThread]);
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    });

    dispatch_group_async(group, queue, ^{
        NSLog(@"task 3 begin : %@",[NSThread currentThread]);
        dispatch_async(queue2, ^{
            NSLog(@"task 3 finish : %@",[NSThread currentThread]);
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    });

    dispatch_group_async(group, queue, ^{
        NSLog(@"task 4 begin : %@",[NSThread currentThread]);
        dispatch_async(queue2, ^{
            NSLog(@"task 4 finish : %@",[NSThread currentThread]);
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"Refresh UI");
    });
}

//使用dispatch_group_enter + dispatch_group_leave。实现testGroup2效果
- (void)testGroup3
{
    dispatch_group_t group =dispatch_group_create();
    dispatch_queue_t globalQueue=dispatch_get_global_queue(0, 0);
    
    dispatch_group_enter(group);
    dispatch_group_async(group, globalQueue, ^{
        NSLog(@"task 1 begin : %@",[NSThread currentThread]);
        dispatch_async(globalQueue, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSLog(@"task 1 finish : %@",[NSThread currentThread]);
                dispatch_group_leave(group);
            });
        });
    });
    
    dispatch_group_enter(group);
    dispatch_group_async(group, globalQueue, ^{
        NSLog(@"task 2 begin : %@",[NSThread currentThread]);
        dispatch_async(globalQueue, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSLog(@"task 2 finish : %@",[NSThread currentThread]);
                dispatch_group_leave(group);
            });
        });
    });
    
    dispatch_group_enter(group);
    dispatch_group_async(group, globalQueue, ^{
        NSLog(@"task 3 begin : %@",[NSThread currentThread]);
        dispatch_async(globalQueue, ^{
            NSLog(@"task 3 finish : %@",[NSThread currentThread]);
            dispatch_group_leave(group);
        });
    });
    
    dispatch_group_enter(group);
    dispatch_group_async(group, globalQueue, ^{
        NSLog(@"task 4 begin : %@",[NSThread currentThread]);
        dispatch_async(globalQueue, ^{
            NSLog(@"task 4 finish : %@",[NSThread currentThread]);
            dispatch_group_leave(group);
        });
    });
    
    dispatch_group_notify(group, dispatch_get_global_queue(0, 0), ^{
        NSLog(@"Refresh UI - %@",[NSThread currentThread]);
    });
}

//GCD信号量
- (void)testSemaphore
{
    int tmpSemaphore = 0;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(tmpSemaphore);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"任务1:%@ - %d",[NSThread currentThread],tmpSemaphore);
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"任务2:%@",[NSThread currentThread]);
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"任务3:%@",[NSThread currentThread]);
        dispatch_semaphore_signal(semaphore);
    });
    
    NSLog(@"func end");
}

//多线程下为array添加成员变量 使用信号量 防止崩溃
- (void)addArrayTest
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    NSMutableArray * arrayM = [NSMutableArray arrayWithCapacity:100];
    
    //@synchronized(self) 也可以
    dispatch_semaphore_t sem = dispatch_semaphore_create(1);
    for (int i = 0; i < 10000; i++)
    {
        dispatch_async(queue, ^{
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            [arrayM addObject:[NSNumber numberWithInt:i]];
            NSLog(@"%@ - %@",[NSNumber numberWithInt:i], [NSThread currentThread]);
            dispatch_semaphore_signal(sem);
        });
    }
}

//使用信号量 控制最大并发数
- (void)GCDmaxThreadTest:(int)maxCount
{
    dispatch_queue_t concrentQueue = dispatch_queue_create("concrentQueue", DISPATCH_QUEUE_CONCURRENT);
    
    //如果maxCount为1,则变为串行队列,说明信号量可以作为锁使用
    dispatch_semaphore_t sem = dispatch_semaphore_create(maxCount);
    for (int i = 0; i < 10; i++)
    {
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        dispatch_async(concrentQueue, ^{
            NSLog(@"任务:%d开始执行 - %@",i + 1, [NSThread currentThread]);
            sleep(2);
            NSLog(@"任务:%d完成",i + 1);
            dispatch_semaphore_signal(sem);
        });
    }
}

//dispatch_barrier_async 栅栏函数
- (void)GCDBarrierTest
{
//    dispatch_queue_t queue = dispatch_get_global_queue(0, 0); //导致栅栏函数无用
//    dispatch_queue_t queue = dispatch_queue_create("barrierTest", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t queue = dispatch_queue_create("barrierTest", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(queue, ^{
        NSLog(@"任务1 : %@",[NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        sleep(1);
        NSLog(@"任务2 : %@",[NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        NSLog(@"任务3 : %@",[NSThread currentThread]);
    });
    
    NSLog(@"同步栅栏前");
    //同步栅栏函数会阻塞当前线程等待在栅栏之前提交的任务都执行完并且自己的block也执行完毕,才会继续往下走
    dispatch_barrier_sync(queue, ^{
        NSLog(@"同步栅栏任务执行 : %@",[NSThread currentThread]);
    });
    NSLog(@"同步栅栏后");

    dispatch_async(queue, ^{
        NSLog(@"任务4 : %@",[NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        sleep(1);
        NSLog(@"任务5 : %@",[NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        NSLog(@"任务6 : %@",[NSThread currentThread]);
    });
    
    NSLog(@"异步栅栏前");
    //异步栅栏函数不会阻塞线程,直接返回。
    dispatch_barrier_async(queue, ^{
        NSLog(@"异步栅栏任务执行 : %@",[NSThread currentThread]);
    });
    NSLog(@"异步栅栏后");
    
    dispatch_async(queue, ^{
        NSLog(@"任务7 : %@",[NSThread currentThread]);
    });
}

//dispatch_once_t 只执行一次
//dispatch_apply 迭代 同步函数
- (void)GCDRunOnceTest
{
    dispatch_queue_t queue = dispatch_queue_create("GCDRunOnceTestConcurrent", DISPATCH_QUEUE_CONCURRENT);
    
    //提供一个并发队列 会在不同线程 并发的迭代 但是会阻塞当前线程
    dispatch_apply(4, queue, ^(size_t index) {
        NSLog(@"1.循环 %zd 次 - %@",index, [NSThread currentThread]);
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"执行一次");
            sleep(2);
        });
    });
    
    dispatch_apply(4, queue, ^(size_t index) {
        NSLog(@"2.循环 %zd 次 - %@",index, [NSThread currentThread]);
    });
    
    //如果当前队列是串行队列,而且在当前串行队列中使用dispatch_apply指定当前队列为迭代队列,会死锁
    NSLog(@"准备主线程添加迭代");
    dispatch_apply(4, dispatch_get_main_queue(), ^(size_t index) {
        NSLog(@"死锁");
    });
}

//dispatch_after不会阻塞线程。延迟指定时间when后,提交block任务到队列queue。注意:并不是延时执行任务
- (void)GCDAfterTest
{
    NSLog(@"dispatch_after 之前");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"dispatch_after");   //延迟2s后提交任务
    });
    NSLog(@"dispatch_after 之后");
}

//挂起一个队列
- (void)GCDtestSuspend
{
    //test1
//    dispatch_queue_t queue = dispatch_get_global_queue(0, 0); // dispatch_suspend对全局并发队列无效
    //test2
//    dispatch_queue_t queue = dispatch_queue_create(NULL, 0); // dispatch_suspend 对串行队列有效
    //test3
    dispatch_queue_t queue = dispatch_queue_create("concurrentQueue", DISPATCH_QUEUE_CONCURRENT); // dispatch_suspend 对自己创建的并发队列有效
    dispatch_async(queue, ^{
        [[NSThread currentThread] setName:@"customThread-1"];
        for (int i = 0 ; i < 10; i ++)
        {
            NSLog(@"任务1 - %d - %@", i, [NSThread currentThread]);
            sleep(1);
        }
        NSLog(@"任务1 执行完毕");
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //之后添加进队列的任务将暂停执行,之前添加的不受影响
        dispatch_suspend(queue);
        NSLog(@"挂起队列");

        //继续添加新的任务,需要等到dispatch_resume(queue)才会执行这个任务
        dispatch_async(queue, ^{
            [[NSThread currentThread] setName:@"customThread-2"];
            for (int i = 0 ; i < 10; i ++)
            {
                NSLog(@"任务2 - %d - %@",i,[NSThread currentThread]);
                sleep(1);
            }
            NSLog(@"任务2 执行完毕");
        });
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"恢复队列");
        dispatch_resume(queue);
    });
}

static dispatch_source_t timer = nil;
//DISPATCH_SOURCE_TYPE_TIMER 定时器
- (void)GCDSourceTest
{
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), 3 * NSEC_PER_SEC, 0);     //dispatch_time     默认时钟,系统休眠他也休眠
    dispatch_source_set_timer(timer, dispatch_walltime(DISPATCH_TIME_NOW, 0), 3 * NSEC_PER_SEC, 0); //dispatch_walltime 钟表时间,相对准确
    dispatch_source_set_event_handler(timer, ^{
        NSLog(@"timer响应了");
    });
    //启动timer
    dispatch_resume(timer);
}

//DISPATCH_SOURCE_TYPE_DATA_ADD: dispatch_source_set_event_handler的block只执行一次。这样做可以把5次响应结果连接起来,组成一个任务，让主线程去调用。
- (void)GCDSourceTest2
{
    dispatch_source_t  source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0,dispatch_get_main_queue());
    dispatch_source_set_event_handler(source, ^{
        NSLog(@"%lu 人已报名",dispatch_source_get_data(source));
    });
    dispatch_resume(source);
    dispatch_apply(5, dispatch_get_global_queue(0, 0), ^(size_t index) {
        NSLog(@"用户%zd 报名郊游",index);
        dispatch_source_merge_data(source, 1); // 触发事件,传递数据
    });
}

- (void)maxThreadCountTest
{
//    dispatch_queue_t concurrentQueue = dispatch_queue_create("MaxQueuee", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    for (int i = 0; i < 1000; i++)
    {
        dispatch_async(concurrentQueue, ^{
            NSLog(@"%@",[NSThread currentThread]);
        });
    }
}
@end
