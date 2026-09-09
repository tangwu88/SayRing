package com.example.yc_product_plugin;

/** The vendor wrapper prints private device/health maps; disable it in all builds. */
final class Log {
    private Log() {}
    static int d(String tag, String message, Throwable... errors) { return 0; }
    static int i(String tag, String message, Throwable... errors) { return 0; }
    static int w(String tag, String message, Throwable... errors) { return 0; }
    static int e(String tag, String message, Throwable... errors) { return 0; }
}
