part of '../prototype_pages.dart';

class SecurityCenterPage extends StatelessWidget {
  const SecurityCenterPage({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.accountAndSecurity)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('security-reset-password'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => controller.isGlobalEdition
                          ? GlobalAuthPage(
                              controller: controller,
                              resetPassword: true,
                            )
                          : PasswordRecoveryPage(controller: controller),
                    ),
                  ),
                  leading: const Icon(Icons.password_rounded),
                  title: Text(context.l10n.resetPassword),
                  subtitle: Text(
                    controller.isGlobalEdition
                        ? context.l10n.verifyContactToReset
                        : uiCopy(context, "验证手机号后重新设置"),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.phonelink_lock_outlined),
                  title: Text(context.l10n.loginProtectionTitle),
                  subtitle: Text(context.l10n.serviceUnavailable),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShoppingCartPage extends StatelessWidget {
  const ShoppingCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.cart)),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: FeatureStateCard(
          message: uiCopy(context, "购物车暂时无法使用"),
          detail: uiCopy(context, "你可以从商品详情页直接选择规格并购买。"),
          icon: Icons.shopping_cart_outlined,
        ),
      ),
    );
  }
}

class AfterSalesPage extends StatelessWidget {
  const AfterSalesPage({this.orderNumber, super.key});

  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.applyAfterSales)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FeatureStateCard(
          message: uiCopy(context, "此功能暂时无法使用，请稍后再试"),
          detail: orderNumber == null
              ? uiCopy(context, "售后服务开通后，可从订单详情提交申请。")
              : uiCopy(
                  context,
                  "订单 {p0} 的售后服务开通后，可在这里提交申请。",
                  parameters: [orderNumber],
                ),
          icon: Icons.support_agent_rounded,
        ),
      ),
    );
  }
}
