//
//  FuncType.h
//  CE_BleSDK
//
//  Created by cxq on 2017/1/14.
//  Copyright © 2017年 celink. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, K6_DataFuncType) {
    DATA_TYPE_NULL = 0,

    /* 1.device to app cmdType (1-100) */
    DEV_TO_APP_START_TYPE = 1,
    DATA_TYPE_DEVINFO,              // 0x02
    DATA_TYPE_BATTERY_INFO,         // 0x03
    DATA_TYPE_REAL_SPORT,           // 0x04
    DATA_TYPE_HISTORY_SPORT,        // 0x05
    DATA_TYPE_SLEEP,                // 0x06
    DATA_TYPE_REAL_HEART,           // 0x07
    DATA_TYPE_HISTORY_HEART,        // 0x08
    DATA_TYPE_DEV_SYNC,             // 0x09
    DATA_TYPE_MIX_SPORT,            // 0x0a
    DATA_TYPE_FIND_PHONE_OR_DEVICE, // 0x0b
    DATA_TYPE_BLE_PAIR_STATUS,      // 0x0c
    DATA_TYPE_USER_CHANGE,          // 0x0d
    DATA_TYPE_MUSIC_CONTROL,        // 0x0e
    DATA_TYPE_CALL_CONTROL_TO_APP,  // 0x0f
    DATA_TYPE_GSENSOR_TEST,         // 0x10
    DATA_TYPE_EXERCISE_HEART,       // 0x11
    DATA_TYPE_REAL_BP,              // 0x12
    DATA_TYPE_REAL_ECG,             // 0x13
    DATA_TYPE_REAL_O2,              // 0x14
    DATA_TYPE_HR_CONTROL,           // 0x15
    DATA_TYPE_FUNCTION_CONTROL,     // 0x16
    DATA_TYPE_HARDWARE_INFO,        // 0x17
    DATA_TYPE_REAL_HR,              // 0x18 自动测心率
    DATA_TYPE_BTEDR_ADDR,           // 0x19
    DATA_TYPE_QR_CODE_INFO = 26,    //
    DATA_TYPE_QR_CODE_DEL = 27,     //
    DATA_TYPE_QR_CODE_CLEAN = 28,   // 二维码清空
    DATA_TYPE_IPHONE_RESOLUTION,    // 发送手机分别率
    DATA_TYPE_SMS_REPLAY,           // 快捷回复（安卓）
    DATA_TYPE_ALIPAY_RAW_DATA,      // 支付宝透传通道
    DATA_TYPE_HISTORY_O2 = 40,      // 自动血氧
    DATA_TYPE_HISTORY_HRV = 42,     // 自动心率异变
    DATA_TYPE_GESTURE_CONFIG = 44,  // 手势控制配置选项
    DATA_TYPE_REAL_HRV = 45,        // 手动心率异变性
    DATA_TYPE_HISTORY_TEMP = 47,    // 皮肤温度历史数据
    DATA_TYPE_SET_VALUABLE_ASSISTANT = 48,        // 本地左右手状态上传
    DATA_TYPE_HEART_PPG = 56, //心率测量 PPG 数据开关控制和数据上传
    DATA_TYPE_GSENSOR_RAW = 57, //Gensor原始数据

    DATA_TYPE_REAL_HRV_METRICS = 60,   // active HRV real-time result (16 bytes)
    DATA_TYPE_HISTORY_HRV_METRICS = 61,     // 61, automatic RRI-HRv history result(16 bytes) 
    DATA_TYPE_REAL_RRI_HRV = 62,       // 62, APP command only: start/stop active RRI-HRV
    
    DEV_TO_APP_END_TYPE = 100,      // 0x64

    /* 2.app to device cmdType (101-200) */
    APP_TO_DEV_START_TYPE = 101,
    DATA_TYPE_USERINFO,            // 0x66  102
    DATA_TYPE_LANGUAGE_SETTING,    // 0x67  103
    DATA_TYPE_TIME,                // 0x68  104
    DATA_TYPE_WEATHER,             // 0x69  105
    DATA_TYPE_ALARM,               // 0x6a  106
    DATA_TYPE_MESSAGE_NOTICE,      // 0x6b  107
    DATA_TYPE_APP_CLOSE,           // 0x6c  108
    DATA_TYPE_SET_DATA_SWITCH,     // 0x6d  109
    DATA_TYPE_APP_SYNC,            // 0x6e  110
    DATA_TYPE_SET_TARGET,          // 0x6f  111
    DATA_TYPE_OPEN_BLE_PAIR,       // 0x70  112
    DATA_TYPE_MUSIC_CONTENT,       // 0x71  113
    DATA_TYPE_SITTING_REMIND,      // 0x72  114
    DATA_TYPE_FORGET_DISTURB,      // 0x73  115
    DATA_TYPE_PHOTOGRAPH_ONOFF,    // 0x74  116
    DATA_TYPE_CALL_CONTROL_TO_DEV, // 0x75  117
    DATA_TYPE_RESET,               // 0x76  118
    DATA_TYPE_SHUTDOWN,            // 0x77  119 关机
    DATA_TYPE_PAIR_FINISH,         // 0x78  120
    DATA_TYPE_UNIT_SETTING,        // 0x79  121
    DATA_TYPE_CALL_ALARM,          // 0x7a  122
    DATA_TYPE_MESSAGE_ALARM,       // 0x7b  123
    DATA_TYPE_MESSAGE_SWITCH,      // 0x7c  124
    DATA_TYPE_TARGET_ALARM,        // 0x7d  125
    DATA_TYPE_DRINK_ALARM,         // 0x7e  126
    DATA_TYPE_HAND_RISE_SWITCH,    // 0x7f  127
    DATA_TYPE_HEART_AUTO_SWITCH,   // 0x80  128
    DATA_TYPE_WATCH_SETTING,       // 0x81  129
    DATA_TYPE_APP_SPORT,           //      130
    DATA_TYPE_WATCH_FACE_SYNC,     //      131
    DATA_TYPE_WATCH_FACE_INFO,     //      132
    DATA_TYPE_WOMAN_STAGE_INFO,    //      133
    DATA_TYPE_WATCH_FACE_START,    //      134
    DATA_TYPE_CONTACT_ADD,         // 0x87  135
    DATA_TYPE_CONTACT_DELETE,      // 0x88  136
    DATA_TYPE_CONTACT_CLEAR,       // 0x89  137
    DATA_TYPE_CONTACT_SYNC,        // 0x8a  138
    DATA_TYPE_WEATHER_REAL_TIME,   //      139
    DATA_TYPE_PHOTO_WATCHFACE_DEL, //      140
    DATA_TYPE_POWER_LOGO_DEL,      //      141
    DATA_TYPE_TEST_TOOL,
    DATA_TYPE_MOTION_GAME = 143, // 142 体感游戏开关
    DATA_TYPE_MOTION_DATA = 144, // 143 体感sensor数据

    DATA_TYPE_EXTERN_WEATHER = 150, // 天气
    DATA_TYPE_LOCATION_INFO = 152,  // 当前地理位置

    DATA_TYPE_SET_LEFT_RIGHT_HAND = 157,  // 设置左右手佩戴
    
    APP_TO_DEV_END_TYPE = 200,

    /* 3.No use (201-255) */
    DATA_TYPE_OTA_STATUS = 201,
    DATA_TYPE_OTA_DATA,
    DATA_TYPE_TEST_DEBUG,
    DATA_TYPE_APP_TEST,
    DATA_TYPE_FACTORY_TEST = 205, // 205

    DATA_TYPE_LEAKLIGHT_TEST, // 漏光测试
    DATA_TYPE_CLEAN_DATA, // 清除数据
};

// 1.3 命令类型：
typedef enum
{
    K6_CMD_TYPE_NULL = 0,
    K6_CMD_TYPE_SEND,        // 发送命令
    K6_CMD_TYPE_SEND_NO_ACK, // 无应答的发送命令
    K6_CMD_TYPE_REQUEST,     // 请求命令
    K6_CMD_TYPE_ACK,         // 应答命令
} K6_CMD_TYPE;

typedef NS_ENUM(NSInteger, CheckReceiveType) {
    ReceivePackageAck,                // 接收数据为ACK包
    ReceiveFirstPackage,              // 接收新数据的第一个包，非ACK数据包
    ReceiveFirstPackageAndEndPackage, // 接收新数据的第一个包也是最后一个包，非ACK数据包
    ReceiveEndPackage,                // 接收新数据最后一个包
    ReceiveNeedMore,                  // 接收到数据，但不是最后一个，需要接收更多包
    ReceiveSerialNumberError,         // 接收数据的流水号不对
    ReceivePackageHeaderError,        // 接收数据的包头不对

    receive_unknown_more // 未知错误
};

typedef enum
{
    MUSIC_CMD_NULL = 0,
    MUSIC_CMD_PLAY,     // 播放音乐
    MUSIC_CMD_PAUSE,    // 暂停音乐
    MUSIC_CMD_STOP,     // 关闭音乐
    MUSIC_CMD_BACKWARD, // 上一首
    MUSIC_CMD_FORWARD,  // 下一首
    MUSIC_CMD_CONTENT,  // 获取歌曲内容
} MUSIC_CMD_TYPE;

/**  OTA 升级状态 */
typedef enum
{
    OTA_NONE = 0,                                               // 未升级
    OTA_RUNING,                                                 // 正在升级过程中
    OTA_FINISH_SUCCESS,                                         // 升级成功
    OTA_FINISH_WRONG,                                           // 升级错误
    OTA_IMG_SIZE_ERROR,                                         // 镜像文件的总长度错误
    OTA_IMG_CRC16_ERROR,                                        // 镜像文件的CRC16值错误
    OTA_ITEM_HEAD_LEN_ERROR,                                    // 单个条目头的长度值错误，
    OTA_ITEM_HEAD_LEN_ERROR_ALL = OTA_ITEM_HEAD_LEN_ERROR + 10, // 范围结束
    OTA_ITEM_MEDIA_ERROR,                                       // 单个条目的存储介质错误
    OTA_ITEM_MEDIA_ERROR_ALL = OTA_ITEM_MEDIA_ERROR + 10,       // 范围结束
    OTA_ITEM_SIZE_ERROR,                                        // 单个条目的文件长度错误
    OTA_ITEM_SIZE_ERROR_ALL = OTA_ITEM_SIZE_ERROR + 10,         // 范围结束
    OTA_ITEM_CRC16_ERROR,                                       // 单个条目文件的CRC16错误，
    OTA_ITEM_CRC16_ERROR_ALL = OTA_ITEM_CRC16_ERROR + 10,       // 范围结束
} OTA_STATUS_TYPE;

/**  OTA 文件类型 */
typedef enum
{
    FILE_TYPE_NULL = 0,
    FILE_TYPE_CUSTOMER,
    FILE_TYPE_HARDWARE,
    FILE_TYPE_CODE,
    FILE_TYPE_PIC,
    FILE_TYPE_FONT,
    FILE_TYPE_DATA,
} OTA_FILE_TYPE;

/**  OTA 数据存储介质类型 */
typedef enum
{
    MEDIA_MCU_FLASH = 0, // 内部flash
    MEDIA_SPI_FLASH      // 外部 spi flash
} OTA_FILE_MEDIA_TYPE;

/**  电话控制，暂时不做处理 */
typedef enum
{
    CALL_CMD_NULL = 0,
    CALL_CMD_ANSWER_CALL, // 接听电话
    CALL_CMD_HANGUP_CALL, // 挂断电话
    CALL_CMD_SOUND_OFF,   // 静音
} CALL_CMD_TYPE;

typedef NS_ENUM(NSInteger, ParseType) {
    ParseAckDataSuccess,
    ParseAckDataCrc16Error,
    ParseAckDataError,

    ParseDataSuccess,
    ParseDataCrc16Error,
    ParseSerialNumberError,

    parse_unknown_more
};

typedef NS_ENUM(NSInteger, CE_ErrorCode) {
    Error_sendFailed = -2000,
    Error_overTime,
    Error_bleClosed,
    Error_deviceDisconnect,
    Error_bleExceptional
};

/**  混杂数据 的运动类型 */
typedef enum
{
    MIX_SPORT_NULL = 0,

    MIX_SPORT_BREATHE,         // 呼吸
    MIX_SPORT_CYCLING,         // 骑车或室外骑车
    MIX_SPORT_CYCLING_INDOOR,  // 室内骑车
    MIX_SPORT_RUNNING_MACHINE, // 跑步机或室内跑步
    MIX_SPORT_RUN,             // 跑步或室外跑步

    MIX_SPORT_SWIM,      // 游泳
    MIX_SPORT_WALK,      // 走路
    MIX_SPORT_WEIGHT,    // 举重
    MIX_SPORT_YOGA,      // 瑜咖
    MIX_SPORT_BADMINTON, // 羽毛球

    MIX_SPORT_BASKETBALL,    // 篮球
    MIX_SPORT_SKIP,          // 跳绳
    MIX_SPORT_FREE_EXERCISE, // 自由锻炼
    MIX_SPORT_FOOTBALL,      // 足球
    MIX_SPORT_CLIMBING,      // 爬山

    MIX_SPORT_PINGPONG,  // 乒乓球
    MIX_SPORT_BOWLING,   // 保龄球
    MIX_SPORT_OPENWATER, // 开放水域
    MIX_SPORT_DANCING,   // 跳舞
    MIX_SPORT_DUMBBELLS, // 哑铃

    MIX_SPORT_HULOHOOP,   // 呼啦圈
    MIX_SPORT_STAIRSMOVE, // 楼梯运动
    MIX_SPORT_STEPPER,    // 踏步机
    MIX_SPORT_TRIATHLON,  // 铁人三项
    MIX_SPORT_SITUPS,     // 仰卧起坐

    MIX_SPORT_SKI,                // 滑雪
    MIX_SPORT_BILLIARDS,          // 台球
    MIX_SPORT_ELLIPTICAL_MACHINE, // 椭圆机
    MIX_SPORT_TRAIL_RUNNING,      // 越野跑
    MIX_SPORT_AEROBICS,           // 健美操

    MIX_SPORT_PILATES,         // 普拉提
    MIX_SPORT_SHUTTLECOCK,     // 踢毽子
    MIX_SPORT_SPIN,            // 旋转
    MIX_SPORT_WALKING_MACHINE, // 走步机
    MIX_SPORT_CRICKET,         // 板球

    MIX_SPORT_VOLLEYBALL,    // 排球
    MIX_SPORT_JUDO,          // 柔道
    MIX_SPORT_KARATE,        // 空手道
    MIX_SPORT_TAEKWONDO,     // 跆拳道
    MIX_SPORT_ROCK_CLIMBING, // 攀岩

    MIX_SPORT_HOCKEY,               // 曲棍球
    MIX_SPORT_WRESTING,             // 摔跤
    MIX_SPORT_ROWING,               // 赛艇
    MIX_SPORT_MOUNTAIN_BIKING = 44, // 山地自行车 /山地摩托车
    MIX_SPORT_MOTOCROSS = 45,       // 越野摩托车

    MIX_SPORT_ROWING_MACHINE = 46, // 划船机
    MIX_SPORT_BALLET = 47,         // 芭蕾舞
    MIX_SPORT_STREET_DANCE = 48,   // 街舞
    MIX_SPORT_JAZZ = 49,           // 爵士
    MIX_SPORT_POLE_DANCE = 50,     // 钢管舞

    MIX_SPORT_FOLK_DANCE = 51,   // 民族舞
    MIX_SPORT_BREAK_DANCE = 52,  // 霹雳舞
    MIX_SPORT_MARTIAL_ARTS = 53, // 武术
    MIX_SPORT_TAI_CAI = 54,      // 太极
    MIX_SPORT_JUJITSU = 55,      // 柔术

    MIX_SPORT_KENDO = 56,            // 剑道
    MIX_SPORT_BEACH_FOOTBALL = 57,   // 沙滩足球
    MIX_SPORT_BEACH_VOLLEYBALL = 58, // 沙滩排球
    MIX_SPORT_BASEBALL = 59,         // 棒球
    MIX_SPORT_SOFTBALL = 60,         // 垒球

    MIX_SPORT_WATER_POLO = 61,         // 水球
    MIX_SPORT_CROSSCOUNTRYSKIING = 62, // 越野滑雪
    MIX_SPORT_OUTDOOR_SKATING = 63,    // 户外滑冰
    MIX_SPORT_SLED = 64,               // 雪橇
    MIX_SPORT_SNOWMOBILE = 65,         // 雪地摩托

    MIX_SPORT_FRISBEE = 66,        // 飞盘
    MIX_SPORT_DARTS = 67,          // 飞镖
    MIX_SPORT_KITE_FLYING = 68,    // 风筝
    MIX_SPORT_AIR_WALKER = 69,     // 空中助行器
    MIX_SPORT_ROLLER_SKATING = 70, // 轮滑

    MIX_SPORT_ARCHERY = 71,      // 射箭
    MIX_SPORT_EQUESTRIAN = 72,   // 马术
    MIX_SPORT_DRIVE = 73,        // 驾驶
    MIX_SPORT_CLIMB_STAIRS = 74, // 爬楼梯
    MIX_SPORT_SQUASH = 75,       // 壁球

    MIX_SPORT_CULING = 76,          // 冰壶
    MIX_SPORT_LINE_SKATING = 77,    // 排队滑冰
    MIX_SPORT_SAILING = 78,         // 帆船
    MIX_SPORT_WATER_SPORTS = 79,    // 水上运动
    MIX_SPORT_PADDLE_BOARDING = 80, // 单桨冲浪

    MIX_SPORT_WATER_SKIING = 81, // 滑水
    MIX_SPORT_KAYAKING = 82,     // 皮划艇
    MIX_SPORT_RAFTING = 83,      // 漂流
    MIX_SPORT_DRAGON_BOAT = 84,  // 龙舟
    MIX_SPORT_POWERBOATING = 85, // 摩托艇

    MIX_SPORT_FINSWIMMING = 86,       // 噗游泳
    MIX_SPORT_ARTISTIC_SWIMMING = 87, // 花样游泳
    MIX_SPORT_KITESURFNG = 88,        // 风筝冲浪
    MIX_SPORT_OPEN_SWIM = 89,         // 公开游泳
    MIX_SPORT_SKATRBOARDING = 90,     // 滑板

    MIX_SPORT_PARKOUT = 91,         // 跑酷
    MIX_SPORT_ATV = 92,             // 沙滩车
    MIX_SPORT_PARAGLIDING = 93,     // 滑翔伞
    MIX_SPORT_OUTDOOR_RUNNING = 94, // 户外跑步
    MIX_SPORT_ON_FOOT = 95,         // 徒步

    MIX_SPORT_KABADDI = 96,       // 卡巴迪
    MIX_SPORT_CORE_TRAINING = 97, // 核心训练
    MIX_SPORT_FLEXIBILITY = 98,   // 柔韧性
    MIX_SPORT_GYMNASTICS = 99,    // 体操
    MIX_SPORT_STRETCHING = 100,   // 伸展运动

    MIX_SPORT_STRENGTH = 101,          // 力量
    MIX_SPORT_CROSS_TRAINING = 102,    // 交叉训练
    MIX_SPORT_PHYSICAL_TRAINING = 103, // 体能训练
    MIX_SPORT_BARBELL = 104,           // 杠铃
    MIX_SPORT_DEADLIFT = 105,          // 硬拉

    MIX_SPORT_UPPER_BODY = 106,           // 上半身
    MIX_SPORT_FUNCTIONALL_TRAINING = 107, // 功能训练
    MIX_SPORT_BURPEE = 108,               // 波比
    MIX_SPORT_BACK_EXERCISE = 109,        // 背部训练
    MIX_SPORT_LOWER_BODY = 110,           // 下半身

    MIX_SPORT_ABS = 111,            // 腹肌
    MIX_SPORT_HIIT = 112,           // 燃脂
    MIX_SPORT_LNDOOR_WALKING = 113, // 室内步行
    MIX_SPORT_SQUARE_DANCING = 114, // 广场舞
    MIX_SPORT_BELLY_DANCE = 115,    // 肚皮舞

    MIX_SPORT_ZUMBA = 116,       // 尊巴舞
    MIX_SPORT_LATIN_DANCE = 117, // 拉丁舞
    MIX_SPORT_JAZZ_DANCE = 118,  // 爵士舞
    MIX_SPORT_BOXING = 119,      // 拳击
    MIX_SPORT_MUAY_THAI = 120,   // 泰拳

    MIX_SPORT_FENCING = 121,            // 击剑
    MIX_SPORT_HANDBALL = 122,           // 手球
    MIX_SPORT_SHUTTLECOCKKICKING = 123, // 毽球
    MIX_SPORT_SPEAK_TAKRAW = 124,       // 藤球
    MIX_SPORT_LCE_SKATING = 125,        // 滑冰

    MIX_SPORT_LCE_HOCKEY = 126,   // 冰球
    MIX_SPORT_BOBSLEIGH = 127,    // 有舵雪橇
    MIX_SPORT_TUG_OF_WAR = 128,   // 拔河
    MIX_SPORT_HULA_HOOP = 129,    // 呼啦圈
    MIX_SPORT_HOUSE_RIDING = 130, // 骑马

    MIX_SPORT_FISHING = 131,     // 钓鱼
    MIX_SPORT_ATHLETICS = 132,   // 田径
    MIX_SPORT_AUTO_RACING = 133, // 赛车
    MIX_SPORT_GOALBALL = 134,    // 门球
    MIX_SPORT_GOLF = 135,        // 高尔夫

    MIX_SPORT_HURDLE = 136,          // 跨栏
    MIX_SPORT_RUGBY = 137,           // 橄榄球
    MIX_SPORT_BIATHION_WINTER = 138, // 冬季两项
    MIX_SPORT_BOOSTER = 139,         // 助推器
    MIX_SPORT_TENNIS = 140,          // 网球

    MIX_SPORT_MARATHON = 141,          // 马拉松
    MIX_SPORT_JUMPING_JACK = 142,      // 开合跳
    MIX_SPORT_MOUNTAIN_BIKING_1 = 143, // 山地摩托车
    MIX_SPORT_LONG_JUMP = 144,         // 跳远
    MIX_SPORT_BOATING = 145,           // 划船
} MIX_SPORT_TYPE;
