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

    @Test fun `care invitations require the exact route and intact one time code`() {
        val invite = "https://app.saydian.cn/global/say-ring/invite#ABCDEFGHJKLMNPQRSTUV"
        assertTrue(RingWechatLinkPolicy.valid(appId, invite))
        for (invalid in listOf(
            invite + "W",
            invite.replace("ABCDEFGHJKLMNPQRSTUV", "I".repeat(20)),
            invite.replace("/invite#", "/invite?title=anything#"),
            invite.replace("/invite#", "/inv%69te#"),
            invite.replace("app.saydian.cn", "app.saydian.cn.evil.example"),
            invite.replace("https:", "http:"),
            invite.replace("#A", "#%41"),
            invite.replace("/invite#", "/respond#"),
        )) assertFalse(invalid, RingWechatLinkPolicy.valid(appId, invalid))
    }

    @Test fun `product cards allow only the first party product route and a bounded ID`() {
        val prefix = "https://app.saydian.cn/global/saidian-mall/#/pages/product/index?id="
        for (id in listOf("123", "uuid-product", "A".repeat(180))) {
            assertTrue(RingWechatLinkPolicy.valid(appId, prefix + id))
        }
        for (invalid in listOf(
            prefix,
            prefix + "A".repeat(181),
            prefix + "123&redirect=https://evil.example",
            prefix.replace("app.saydian.cn", "app.saydian.cn.evil.example") + "123",
            prefix.replace("/pages/product/index", "/pages/order/index") + "123",
            prefix.replace("/saidian-mall/", "/saidian-mall/?redirect=other") + "123",
        )) assertFalse(invalid, RingWechatLinkPolicy.valid(appId, invalid))
    }
}
