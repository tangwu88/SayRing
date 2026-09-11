# Veepoo's scanner passes SearchResponse callbacks through java.lang.reflect.Proxy.
# R8 must not merge or rewrite these SDK callback types to concrete classes.
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
-keep class com.veepoo.** { *; }
-keep interface com.veepoo.** { *; }
-keep class com.inuker.bluetooth.library.** { *; }
-keep interface com.inuker.bluetooth.library.** { *; }

# JL's authentication libraries register native methods by their Java names.
# Keep these names in release builds so libjl_auth can resolve setLinkKey and
# the watch-face/photo-watch-face session can initialize.
-keep class com.jieli.** { *; }
-keep interface com.jieli.** { *; }

# Keep the app-side anonymous callbacks separate from Veepoo's internal callback
# implementations. Horizontal class merging caused $Proxy instances to be cast
# to the merged concrete callback class in the previous release APK.
-keep class cc.saidian.saydian_app.VeepooWearableAdapter** { *; }

# The closed Bluetooth scanner writes scan payloads directly through
# android.util.Log, bypassing the SDK logging flags. Remove every Android log
# call from optimized release builds so device identifiers cannot enter logs.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int wtf(...);
    public static int println(...);
}

# The pinned Yucheng SDK ships optional AliAgent, Realtek OTA and chip-specific
# branches without all of their proprietary runtimes. The app does not expose
# those optional entry points. Keep R8 strict for every other missing class and
# suppress only the exact vendor references reported by AGP.
-dontwarn com.alibaba.fastjson.JSONObject
-dontwarn com.alibaba.fastjson.TypeReference
-dontwarn com.alibaba.fastjson.parser.Feature
-dontwarn com.google.firebase.crashlytics.buildtools.reloc.org.apache.commons.codec.binary.Hex
-dontwarn com.jieli.bt.decryption.HashDecryption
-dontwarn com.realsil.sdk.core.logger.ZLogger
-dontwarn com.realsil.sdk.dfu.image.BinFactory
-dontwarn com.realsil.sdk.dfu.image.LoadParams$Builder
-dontwarn com.realsil.sdk.dfu.image.LoadParams
-dontwarn com.realsil.sdk.dfu.model.BinInfo
-dontwarn com.realsil.sdk.dfu.model.DfuConfig
-dontwarn com.realsil.sdk.dfu.model.OtaDeviceInfo
-dontwarn com.realsil.sdk.dfu.utils.DfuAdapter$DfuHelperCallback
-dontwarn com.realsil.sdk.dfu.utils.GattDfuAdapter
-dontwarn org.apache.commons.lang3.StringUtils
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE
