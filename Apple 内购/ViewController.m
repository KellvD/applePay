//
//  ViewController.m
//  Apple 内购
//
//  Created by 敏捷软件 on 17/1/5.
//  Copyright © 2017年 敏捷软件. All rights reserved.
//

#import "ViewController.h"
#import <StoreKit/StoreKit.h>
#define EnableBuy @"enablebuy"

#define Product1  @"product1" //产品ID
#define Product2  @"product2"
#define Product3  @"product3"
#define Product4  @"product4"
#define Product5  @"product5"
#define Product6  @"product6"
@interface ViewController ()
<
SKPaymentTransactionObserver,
SKProductsRequestDelegate
>


@property (nonatomic, assign) NSInteger selectedProduct;
@end

@implementation ViewController{
    NSArray *productArr;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
   [ button setTitle: @"点击购买"forState:UIControlStateNormal];
    [button addTarget:self action:@selector(startPayClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    
    
    //添加一个交易队列观察者
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    productArr = @[Product1,Product2,Product3,Product4,Product5,Product6];
    
}
#pragma mark - Event response

-(void)startPayClick:(UIButton *)button{
    
    self.selectedProduct = 1;
    /**
     *内购测试
     */
    //判断是否可进行支付
    
    if ([SKPaymentQueue canMakePayments]) {
        
        NSLog(@"----------允许程序内付费--------");
        [self requestProductData:productArr[self.selectedProduct]];
        
    } else {
        NSLog(@"不允许程序内付费");
    }
    
}

#pragma mark ---内购测试

- (void)requestProductData:(NSString *)type {
    //根据商品ID查找商品信息
    NSArray *product = [[NSArray alloc] initWithObjects:type, nil];
    NSSet *nsset = [NSSet setWithArray:product];
    //创建SKProductsRequest对象，用想要出售的商品的标识来初始化， 然后附加上对应的委托对象。
    //该请求的响应包含了可用商品的本地化信息。
    
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
    request.delegate = self;
    [request start];
}
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"-----------收到产品反馈信息--------------");
    NSArray *product = response.products;
    NSLog(@"产品Product ID:%@",response.invalidProductIdentifiers);
    NSLog(@"产品付费数量: %ld", [product count]);
    if ([product count] == 0) {
        return;
    }
    // SKProduct对象包含了在App Store上注册的商品的本地化信息。
    SKProduct *storeProduct = nil;
    for (SKProduct *pro in product) {
        
        NSLog(@"product info");
        NSLog(@"SKProduct 描述信息%@", [pro description]);
        NSLog(@"产品标题 %@" , pro.localizedTitle);
        NSLog(@"产品描述信息: %@" , pro.localizedDescription);
        NSLog(@"价格: %@" , pro.price);
        NSLog(@"Product id: %@" , pro.productIdentifier);
        if ([pro.productIdentifier isEqualToString:productArr[self.selectedProduct]]) {
            storeProduct = pro;
        }
    }
    
    
    SKPayment *payment = [SKPayment paymentWithProduct:storeProduct];
    NSLog(@"--------发送购买请求---------");
    [[SKPaymentQueue defaultQueue ] addPayment:payment];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"请求商品失败%@", error);
    
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"反馈信息结束调用 ");
   
}
-(void) paymentQueue:(SKPaymentQueue *) paymentQueue restoreCompletedTransactionsFailedWithError:(NSError *)error{
    NSLog(@"-------paymentQueue----");
}
//监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction {
    
    for (SKPaymentTransaction *tran in transaction) {
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:
                
                NSLog(@"-----交易完成 --------");
                
                [self completeTransaction:tran];
                [[SKPaymentQueue defaultQueue]finishTransaction:tran];
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"商品加入列表");
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:tran];
                NSLog(@"-----已经购买过该商品 --------");
                [[SKPaymentQueue defaultQueue]finishTransaction:tran];
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"交易失败");
                
                [self failedTransaction:tran];
                break;
                
                
            default:
                break;
        }
    }
}
//交易结束
- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"交易结束!!!!!!!!!!!!!!!");
    
    
    
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 获取到购买凭据
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    //购买完成向后台发送receipt-data，后台校验发送部分略
    NSString *sendString = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];

    //‼️沙盒测试时用
     NSString * str = [[NSString alloc]initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding];
     
     NSString *environment=[self environmentForReceipt:str];
     
     NSURL *StoreURL=nil;
     if ([environment isEqualToString:@"environment=Sandbox"]) {
     
         StoreURL= [[NSURL alloc] initWithString: @"https://sandbox.itunes.apple.com/verifyReceipt"];
     }
     else{
         StoreURL= [[NSURL alloc] initWithString: @"https://buy.itunes.apple.com/verifyReceipt"];
     }
     
    
    
    /*‼️提交审核时用，将沙盒测试部分（171-183行）去掉
    NSURL *StoreURL= [[NSURL alloc] initWithString: @"https://buy.itunes.apple.com/verifyReceipt"];
    */
    
    
    //这个二进制数据由服务器进行验证；zl
    NSData *postData = [NSData dataWithBytes:[sendString UTF8String] length:[sendString length]];
    
    NSMutableURLRequest *connectionRequest = [NSMutableURLRequest requestWithURL:StoreURL];
    
    [connectionRequest setHTTPMethod:@"POST"];
    [connectionRequest setTimeoutInterval:50.0];//120.0---50.0zl
    [connectionRequest setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [connectionRequest setHTTPBody:postData];
    NSString *product = transaction.payment.productIdentifier;
    if ([product length] > 0) {
        
        NSArray *tt = [product componentsSeparatedByString:@"."];
        NSString *bookid = [tt lastObject];
        if ([bookid length] > 0) {
            [self recordTransaction:bookid];
            [self provideContent:bookid];
        }
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}



//记录交易
-(void)recordTransaction:(NSString *)product{
    NSLog(@"-----记录交易--------");
}
//处理下载内容
-(void)provideContent:(NSString *)product{
    NSLog(@"-----下载--------");
}

- (void) failedTransaction: (SKPaymentTransaction *)transaction{
    NSLog(@"失败");
    
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
    }
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    
    
}
- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    // 恢复已经购买的产品
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

//收据的环境判断；
-(NSString * )environmentForReceipt:(NSString * )str
{
    
    str= [str stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    str = [str stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    
    str=[str stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    str=[str stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    
    NSArray * arr=[str componentsSeparatedByString:@";"];
    
    //存储收据环境的变量
    NSString * environment=arr[2];
    return environment;
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
