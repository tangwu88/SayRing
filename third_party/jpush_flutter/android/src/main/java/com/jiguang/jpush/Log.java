package com.jiguang.jpush;

/** Payload logging is disabled independently of Flutter's debug flag. */
final class Log {
    private Log() {}
    static int d(String tag, String message, Throwable... errors) { return 0; }
    static int i(String tag, String message, Throwable... errors) { return 0; }
    static int w(String tag, String message, Throwable... errors) { return 0; }
    static int e(String tag, String message, Throwable... errors) { return 0; }
}
