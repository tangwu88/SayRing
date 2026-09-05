import 'package:flutter/services.dart';

enum StoreKitPurchaseState { verified, cancelled, pending }

class StoreKitTransaction {
  const StoreKitTransaction({
    required this.state,
    required this.productId,
    required this.transactionId,
    required this.appAccountToken,
    required this.signedTransactionInfo,
  });

  final StoreKitPurchaseState state;
  final String productId;
  final String transactionId;
  final String appAccountToken;
  final String signedTransactionInfo;

  factory StoreKitTransaction.fromMap(Map<Object?, Object?> value) {
    final map = value.map((key, value) => MapEntry('$key', value));
    final state = switch ('${map['status'] ?? ''}'.trim().toLowerCase()) {
      'verified' => StoreKitPurchaseState.verified,
      'cancelled' => StoreKitPurchaseState.cancelled,
      'pending' => StoreKitPurchaseState.pending,
      _ => throw const FormatException('苹果购买结果格式不正确'),
    };
    return StoreKitTransaction(
      state: state,
      productId: '${map['productId'] ?? ''}'.trim(),
      transactionId: '${map['transactionId'] ?? ''}'.trim(),
      appAccountToken: '${map['appAccountToken'] ?? ''}'.trim(),
      signedTransactionInfo: '${map['signedTransactionInfo'] ?? ''}'.trim(),
    );
  }
}

abstract interface class StoreKitPurchaseBridge {
  Future<StoreKitTransaction> purchase({
    required String productId,
    required String appAccountToken,
  });

  Future<List<StoreKitTransaction>> restorePurchases();

  Future<bool> finish(String transactionId);
}

class MethodChannelStoreKitPurchaseBridge implements StoreKitPurchaseBridge {
  const MethodChannelStoreKitPurchaseBridge();

  static const channel = MethodChannel('cc.saidian/storekit');

  @override
  Future<StoreKitTransaction> purchase({
    required String productId,
    required String appAccountToken,
  }) async {
    final result = await channel.invokeMapMethod<Object?, Object?>('purchase', {
      'productId': productId,
      'appAccountToken': appAccountToken,
    });
    if (result == null) {
      throw PlatformException(
        code: 'STOREKIT_EMPTY_RESULT',
        message: '苹果购买没有返回结果',
      );
    }
    return StoreKitTransaction.fromMap(result);
  }

  @override
  Future<List<StoreKitTransaction>> restorePurchases() async {
    final values = await channel.invokeListMethod<Object?>('restorePurchases');
    return (values ?? const <Object?>[])
        .whereType<Map>()
        .map(StoreKitTransaction.fromMap)
        .where(
          (transaction) =>
              transaction.state == StoreKitPurchaseState.verified &&
              transaction.transactionId.isNotEmpty &&
              transaction.appAccountToken.isNotEmpty &&
              transaction.signedTransactionInfo.isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<bool> finish(String transactionId) async =>
      await channel.invokeMethod<bool>('finish', {
        'transactionId': transactionId,
      }) ??
      false;
}
