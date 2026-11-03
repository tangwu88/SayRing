package cc.saidian.saydian_app;

/**
 * 厂商 SDK 的安装级重连地址不是业务绑定。只有 App 本轮明确选择的目标可以写入它；
 * 暂停通道只清这项地址缓存，不解绑、不改系统配对、提醒设置或健康记录。
 */
final class CoolWearRecoveryTarget {
    interface Sdk {
        void clearTarget();
        void setTarget(String target);
        void disconnect();
    }

    private volatile long generation;
    private String target;

    long generation() { return generation; }
    boolean isCurrent(long callbackGeneration) { return callbackGeneration == generation; }
    boolean isActive() { return target != null; }

    void initializeIdle(Sdk sdk) {
        if (!isActive()) sdk.clearTarget();
    }

    void activate(String authorizedTarget, Sdk sdk) {
        if (authorizedTarget == null || authorizedTarget.isEmpty()) {
            throw new IllegalArgumentException("An explicit connection target is required");
        }
        generation++;
        target = authorizedTarget;
        try {
            sdk.setTarget(authorizedTarget);
        } catch (RuntimeException failure) {
            target = null;
            generation++;
            throw failure;
        }
    }

    void pause(Sdk sdk) {
        // 先撤销授权：disconnect 若立即回调，也不能重新写回旧地址。
        target = null;
        generation++;
        try {
            sdk.clearTarget();
        } finally {
            sdk.disconnect();
        }
    }

    boolean acceptCallback(long callbackGeneration, boolean connected, Sdk sdk) {
        // 旧主线程队列回调必须直接丢弃，不能清理后来已授权的新目标。
        if (!isCurrent(callbackGeneration)) return false;
        if (isActive()) return true;
        try {
            // SDK 的断线回调会再次启动 timer；两处地址均空时，下一轮会自行停下。
            sdk.clearTarget();
        } finally {
            if (connected) sdk.disconnect();
        }
        return false;
    }
}
