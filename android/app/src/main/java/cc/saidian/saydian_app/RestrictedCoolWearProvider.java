package cc.saidian.saydian_app;

import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;
import android.os.Binder;
import android.os.Process;

import ce.com.cenewbluesdk.BleContentProvider.YDBleContentProvider;

/**
 * The vendor BLE callback writes its provider as Bluetooth UID 1002 on some
 * Android builds, even though the callback runs in our app process. Exporting
 * the vendor provider without this guard would expose SDK session metadata to
 * unrelated apps. Permit only this app and Android's system/Bluetooth UIDs.
 */
public final class RestrictedCoolWearProvider extends YDBleContentProvider {
    private static final int BLUETOOTH_UID = 1002;

    private static void requireTrustedCaller() {
        int uid = Binder.getCallingUid();
        if (uid != Process.myUid() && uid != Process.SYSTEM_UID && uid != BLUETOOTH_UID) {
            throw new SecurityException("CoolWear session provider is app and Bluetooth only");
        }
    }

    @Override public Cursor query(Uri uri, String[] projection, String selection,
                                  String[] selectionArgs, String sortOrder) {
        requireTrustedCaller();
        return super.query(uri, projection, selection, selectionArgs, sortOrder);
    }

    @Override public String getType(Uri uri) {
        requireTrustedCaller();
        return super.getType(uri);
    }

    @Override public Uri insert(Uri uri, ContentValues values) {
        requireTrustedCaller();
        return super.insert(uri, values);
    }

    @Override public int delete(Uri uri, String selection, String[] selectionArgs) {
        requireTrustedCaller();
        return super.delete(uri, selection, selectionArgs);
    }

    @Override public int update(Uri uri, ContentValues values, String selection,
                                String[] selectionArgs) {
        requireTrustedCaller();
        return super.update(uri, values, selection, selectionArgs);
    }
}
