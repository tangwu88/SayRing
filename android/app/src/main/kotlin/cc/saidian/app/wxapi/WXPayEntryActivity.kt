package cn.saydian.ring.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import cc.saidian.saydian_app.AppPaymentStore
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory

class WXPayEntryActivity : Activity(), IWXAPIEventHandler {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWechatIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWechatIntent(intent)
    }

    private fun handleWechatIntent(intent: Intent?) {
        val appId = AppPaymentStore.readWechatAppId(this)
        if (appId.isEmpty() || intent == null) {
            AppPaymentStore.saveWechatResult(this, BaseResp.ErrCode.ERR_COMM, "微信支付回调参数缺失")
            finish()
            return
        }
        val api = WXAPIFactory.createWXAPI(this, appId, false)
        if (!api.handleIntent(intent, this)) {
            AppPaymentStore.saveWechatResult(this, BaseResp.ErrCode.ERR_COMM, "无法处理微信支付结果")
            finish()
        }
    }

    override fun onReq(req: BaseReq?) = Unit

    override fun onResp(resp: BaseResp?) {
        AppPaymentStore.saveWechatResult(
            this,
            resp?.errCode ?: BaseResp.ErrCode.ERR_COMM,
            resp?.errStr,
        )
        finish()
    }
}
