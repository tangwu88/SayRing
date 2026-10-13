part of '../pages.dart';

class AfterSalesPage extends StatefulWidget {
  const AfterSalesPage({
    required this.controller,
    this.order,
    this.orderNumber,
    super.key,
  });

  final AppController controller;
  final Map<String, Object?>? order;
  final String? orderNumber;

  @override
  State<AfterSalesPage> createState() => _AfterSalesPageState();
}

class _AfterSalesPageState extends State<AfterSalesPage> {
  @override
  void initState() {
    super.initState();
    if (widget.order == null) unawaited(widget.controller.loadOrders(null));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.afterSalesService)),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final source = widget.order == null
            ? widget.controller.orders
            : [widget.order!];
        final eligible = source.where((order) {
          final status = int.tryParse('${order['order_status'] ?? ''}');
          return status != null && status > 0;
        }).toList();
        if (eligible.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => widget.controller.loadOrders(null),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(
                  Icons.support_agent_outlined,
                  size: 68,
                  color: SaydianColors.outline,
                ),
                SizedBox(height: 16),
                Text(
                  '暂无可申请售后的订单',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  '已付款订单可按商品提交退款或退货退款申请。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SaydianColors.muted),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            InlineNotice(
              message: context.l10n.afterSalesApplyHint,
              icon: Icons.info_outline_rounded,
              color: SaydianColors.techBlue,
            ),
            const SizedBox(height: 12),
            for (final order in eligible) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '订单号 ${order['order_sn'] ?? widget.orderNumber ?? order['id'] ?? ''}',
                        style: const TextStyle(
                          color: SaydianColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(height: 24),
                      for (final product in _orderProducts(order))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _OrderProductImage(product: product),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${product['product_name'] ?? '商品'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${product['sku_name'] ?? ''}',
                                      style: const TextStyle(
                                        color: SaydianColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _openApply(context, order, product),
                                        child: Text(
                                          '${product['is_customer'] ?? 0}' ==
                                                  '1'
                                              ? '查看售后状态'
                                              : '申请售后',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    ),
  );

  List<Map<String, Object?>> _orderProducts(Map<String, Object?> order) {
    final raw = order['product'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  void _openApply(
    BuildContext context,
    Map<String, Object?> order,
    Map<String, Object?> product,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AfterSalesApplyPage(
          controller: widget.controller,
          order: order,
          product: product,
        ),
      ),
    );
  }
}

class _AfterSalesApplyPage extends StatefulWidget {
  const _AfterSalesApplyPage({
    required this.controller,
    required this.order,
    required this.product,
  });

  final AppController controller;
  final Map<String, Object?> order;
  final Map<String, Object?> product;

  @override
  State<_AfterSalesApplyPage> createState() => _AfterSalesApplyPageState();
}

class _AfterSalesApplyPageState extends State<_AfterSalesApplyPage> {
  final _reason = TextEditingController();
  late final TextEditingController _amount;
  int _refundType = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text:
          '${widget.product['product_money'] ?? widget.product['price'] ?? ''}',
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alreadyApplied = '${widget.product['is_customer'] ?? 0}' == '1';
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.applyAfterSales)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: _OrderProductImage(product: widget.product),
              title: Text('${widget.product['product_name'] ?? '商品'}'),
              subtitle: Text(
                '订单号 ${widget.order['order_sn'] ?? widget.order['id'] ?? ''}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (alreadyApplied)
            InlineNotice(
              message: context.l10n.afterSalesAlreadySubmitted,
              icon: Icons.schedule_rounded,
              color: SaydianColors.orange,
            )
          else ...[
            DropdownButtonFormField<int>(
              initialValue: _refundType,
              decoration: InputDecoration(
                labelText: context.l10n.afterSalesType,
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('仅退款')),
                DropdownMenuItem(value: 2, child: Text('退货退款')),
              ],
              onChanged: (value) => setState(() => _refundType = value ?? 1),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.l10n.requestedAmount,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: context.l10n.afterSalesReason,
                hintText: context.l10n.describeProblem,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '提交中…' : '提交申请'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final productId = int.tryParse('${widget.product['id'] ?? ''}');
    final amount = num.tryParse(_amount.text.trim());
    if (productId == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请检查商品和申请金额')));
      return;
    }
    setState(() => _submitting = true);
    final success = await widget.controller.applyOrderRefund(
      orderProductId: productId,
      refundType: _refundType,
      amount: amount,
      reason: _reason.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '售后申请已提交' : widget.controller.errorMessage ?? '提交失败',
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    required this.controller,
    required this.initialStatus,
    super.key,
  });

  final AppController controller;
  final int? initialStatus;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late int? _status;
  static const _filters = <(int?, String)>[
    (null, '全部'),
    (0, '待支付'),
    (1, '待发货'),
    (2, '待收货'),
    (3, '已完成'),
    (-1, '售后'),
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    unawaited(widget.controller.loadOrders(_status == -1 ? null : _status));
  }

  void _selectStatus(int? value) {
    if (_status == value) return;
    setState(() => _status = value);
    unawaited(widget.controller.loadOrders(value == -1 ? null : value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.myOrders)),
      body: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  for (final filter in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.$2),
                        selected: _status == filter.$1,
                        showCheckmark: false,
                        onSelected: (_) => _selectStatus(filter.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final orders = _status == -1
                    ? widget.controller.orders.where((order) {
                        final status = int.tryParse(
                          '${order['order_status'] ?? ''}',
                        );
                        final products = order['product'];
                        final hasAfterSalesProduct =
                            products is List &&
                            products.whereType<Map>().any(
                              (product) =>
                                  '${product['is_customer'] ?? 0}' == '1',
                            );
                        return (status != null && status < 0) ||
                            '${order['is_customer'] ?? 0}' == '1' ||
                            hasAfterSalesProduct;
                      }).toList()
                    : widget.controller.orders;
                if (orders.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => widget.controller.loadOrders(
                      _status == -1 ? null : _status,
                    ),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 110),
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 68,
                          color: SaydianColors.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.controller.orderStatus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SaydianColors.muted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => widget.controller.loadOrders(
                    _status == -1 ? null : _status,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _OrderCard(
                      controller: widget.controller,
                      order: orders[index],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.controller, required this.order});

  final AppController controller;
  final Map<String, Object?> order;

  @override
  Widget build(BuildContext context) {
    final products = order['product'] is List
        ? order['product'] as List
        : const [];
    final status = switch (int.tryParse('${order['order_status'] ?? ''}')) {
      0 => '待付款',
      1 => '待发货',
      2 => '待收货',
      3 => '已完成',
      4 => '已完成',
      -1 => '申请退款',
      -2 => '退款中',
      -3 => '已退款',
      _ => '订单处理中',
    };
    final statusColor = status.contains('退款') || status.contains('售后')
        ? SaydianColors.danger
        : status == '已完成'
        ? SaydianColors.success
        : SaydianColors.brandRed;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          final id = int.tryParse('${order['id'] ?? ''}');
          if (id == null) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OrderDetailPage(controller: controller, id: id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '订单号 ${order['order_sn'] ?? order['id'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              for (final product in products.whereType<Map>()) ...[
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrderProductImage(product: product),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${product['product_name'] ?? product['title'] ?? '商品'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${product['sku_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SaydianColors.muted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Text(
                                '¥${product['price'] ?? product['product_money'] ?? '--'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '×${product['num'] ?? 1}',
                                style: const TextStyle(
                                  color: SaydianColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '共 ${products.length} 件',
                      style: const TextStyle(
                        color: SaydianColors.muted,
                        fontSize: 14,
                      ),
                    ),
                    Text(context.l10n.amountPaid),
                    Text(
                      '¥${order['pay_money'] ?? '--'}',
                      style: const TextStyle(
                        color: SaydianColors.brandRed,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderProductImage extends StatelessWidget {
  const _OrderProductImage({required this.product});

  final Map product;

  @override
  Widget build(BuildContext context) {
    final raw =
        product['product_picture'] ??
        product['cover'] ??
        product['image'] ??
        product['product_image'];
    final url = normalizeArticleImageUrl('${raw ?? ''}');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: 78,
        child: url.isEmpty
            ? const ColoredBox(
                color: SaydianColors.techBlueSoft,
                child: Icon(Icons.shopping_bag_outlined),
              )
            : SafeNetworkImage(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: SaydianColors.techBlueSoft,
                  child: Icon(Icons.shopping_bag_outlined),
                ),
              ),
      ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    required this.controller,
    required this.id,
    super.key,
  });

  final AppController controller;
  final int id;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, Object?> _order = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await widget.controller.loadOrderDetail(widget.id);
    if (mounted) {
      setState(() {
        _order = value;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _order['product'] is List
        ? _order['product'] as List
        : const [];
    final status = int.tryParse('${_order['order_status'] ?? ''}');
    final receiver = '${_order['receiver_name'] ?? _order['realname'] ?? '--'}';
    final mobile = '${_order['receiver_mobile'] ?? _order['mobile'] ?? '--'}';
    final region = '${_order['receiver_region_name'] ?? ''}'.trim();
    final address =
        '${_order['receiver_address'] ?? _order['address'] ?? '--'}';
    final orderNumber = '${_order['order_sn'] ?? widget.id}';
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.orderDetails)),
      backgroundColor: SaydianColors.canvas,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_order.isEmpty)
                    InlineNotice(
                      message: context.l10n.orderDetailsLoadFailed,
                      icon: Icons.error_outline_rounded,
                      color: SaydianColors.orange,
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            SaydianColors.techBlue,
                            SaydianColors.techIndigo,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 25,
                            backgroundColor: Color(0x2AFFFFFF),
                            foregroundColor: Colors.white,
                            child: Icon(Icons.shopping_bag_outlined),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _orderStatusLabel(status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _orderStatusDescription(status),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: SaydianColors.brandRed,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$receiver  $mobile',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    '$region$address',
                                    style: const TextStyle(
                                      color: SaydianColors.muted,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          for (var index = 0; index < products.length; index++)
                            if (products[index] is Map) ...[
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _OrderProductImage(
                                      product: products[index] as Map,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${(products[index] as Map)['product_name'] ?? '商品'}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${(products[index] as Map)['sku_name'] ?? ''}',
                                            style: const TextStyle(
                                              color: SaydianColors.muted,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '¥${(products[index] as Map)['product_money'] ?? (products[index] as Map)['price'] ?? '--'}',
                                                  style: const TextStyle(
                                                    color:
                                                        SaydianColors.brandRed,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '×${(products[index] as Map)['num'] ?? 1}',
                                                style: const TextStyle(
                                                  color: SaydianColors.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (index != products.length - 1)
                                const Divider(height: 1, indent: 104),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _OrderAmountRow(
                              label: '商品金额',
                              value: '¥${_order['order_money'] ?? '--'}',
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            _OrderAmountRow(
                              label: '实付款',
                              value: '¥${_order['pay_money'] ?? '--'}',
                              emphasized: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _OrderInfoRow(label: '订单编号', value: orderNumber),
                            const SizedBox(height: 10),
                            _OrderInfoRow(
                              label: '下单时间',
                              value: '${_order['created_at'] ?? '--'}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (status != null && status > 0)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'after-sales',
                                ),
                                builder: (_) => AfterSalesPage(
                                  controller: widget.controller,
                                  order: _order,
                                  orderNumber: orderNumber,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.support_agent_outlined),
                            label: Text(context.l10n.applyAfterSales),
                          ),
                        if (status != null && status >= 2)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ShopExpressPage(
                                  controller: widget.controller,
                                  orderId: widget.id,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.local_shipping_outlined),
                            label: Text(context.l10n.viewShipping),
                          ),
                        if (status == 2)
                          FilledButton.icon(
                            key: const Key('confirm-order-receipt'),
                            onPressed: _confirmReceipt,
                            icon: const Icon(Icons.inventory_rounded),
                            label: Text(context.l10n.confirmReceipt),
                          ),
                        if (status == 0)
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ShopPaymentStatusPage(
                                  controller: widget.controller,
                                  orderId: widget.id,
                                  ordersPageBuilder: (_) => OrdersPage(
                                    controller: widget.controller,
                                    initialStatus: 0,
                                  ),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.payment_rounded),
                            label: Text(context.l10n.checkPaymentStatus),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _orderStatusLabel(int? status) => switch (status) {
    0 => '等待付款',
    1 => '等待发货',
    2 => '等待收货',
    3 => '交易完成',
    4 => '交易完成',
    _ => '${_order['order_status_name'] ?? '订单处理中'}',
  };

  String _orderStatusDescription(int? status) => switch (status) {
    0 => '请在订单有效期内完成支付',
    1 => '商家正在准备您的商品',
    2 => '商品已发出，请注意查收',
    3 => '感谢您使用 Say Ring 商城',
    4 => '感谢您使用 Say Ring 商城',
    _ => '订单状态以商城最新数据为准',
  };

  Future<void> _confirmReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmItemReceived),
        content: Text(context.l10n.confirmReceiptHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.notConfirmYet),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirmReceipt),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await widget.controller.confirmOrderReceipt(widget.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '已确认收货' : widget.controller.errorMessage ?? '确认收货失败',
        ),
      ),
    );
    if (success) await _load();
  }
}

class _OrderAmountRow extends StatelessWidget {
  const _OrderAmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        value,
        style: TextStyle(
          color: emphasized ? SaydianColors.brandRed : SaydianColors.ink,
          fontSize: emphasized ? 19 : 15,
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    ],
  );
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 78,
        child: Text(label, style: const TextStyle(color: SaydianColors.muted)),
      ),
      Expanded(child: SelectableText(value)),
    ],
  );
}
