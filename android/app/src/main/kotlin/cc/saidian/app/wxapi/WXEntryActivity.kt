package cc.saidian.app.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import cc.saidian.saydian_app.AppWechatAuthStore
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory

class WXEntryActivity : Activity(), IWXAPIEventHandler {
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
        val appId = AppWechatAuthStore.readWechatAppId(this)
        if (appId.isEmpty() || intent == null) {
            AppWechatAuthStore.saveWechatResult(
                this,
                BaseResp.ErrCode.ERR_COMM,
                null,
                null,
                null,
            )
            finish()
            return
        }
        val api = WXAPIFactory.createWXAPI(this, appId, false)
        if (!api.handleIntent(intent, this)) {
            AppWechatAuthStore.saveWechatResult(
                this,
                BaseResp.ErrCode.ERR_COMM,
                null,
                null,
                null,
            )
            finish()
        }
    }

    override fun onReq(req: BaseReq?) = Unit

    override fun onResp(resp: BaseResp?) {
        val auth = resp as? SendAuth.Resp
        Log.i(
            "SaidianWechatAuth",
            "callback errorCode=${auth?.errCode ?: resp?.errCode ?: BaseResp.ErrCode.ERR_COMM} " +
                "hasCode=${!auth?.code.isNullOrBlank()} hasOpenId=${!auth?.openId.isNullOrBlank()}",
        )
        AppWechatAuthStore.saveWechatResult(
            this,
            auth?.errCode ?: resp?.errCode ?: BaseResp.ErrCode.ERR_COMM,
            auth?.code,
            auth?.state,
            auth?.openId,
        )
        finish()
    }
}
