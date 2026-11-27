package cc.saidian.saydian_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RingWechatLinkPolicyTest {
    private val appId = "wx12345678fixture"
    private val token = "A".repeat(43)
    private val link = "https://app.saydian.cn/global/say-ring/share?title=fixture#$token"

    @Test fun `native share accepts only an intact first party report link`() {
        assertTrue(RingWechatLinkPolicy.valid(appId, link))
        for (invalid in listOf(
            link.replace("https:", "http:"),
            link.replace("app.saydian.cn", "app.saydian.cn.evil.example"),
            link.replace("app.saydian.cn", "attacker@app.saydian.cn"),
            link.replace("app.saydian.cn", "app.saydian.cn:444"),
            link.replace("/share?", "/invite?"),
            link.replace("/share?", "/sh%61re?"),
            link.replace("#$token", "#short"),
            link.replace("#$token", "#%41" + "A".repeat(42)),
            link + "A",
        )) assertFalse(invalid, RingWechatLinkPolicy.valid(appId, invalid))
        assertFalse(RingWechatLinkPolicy.valid("missing", link))
    }
}
