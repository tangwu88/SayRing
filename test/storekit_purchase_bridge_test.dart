import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/storekit_purchase_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          MethodChannelStoreKitPurchaseBridge.channel.name,
          null,
        );
  });

  test(
    'purchase sends product and account token and parses signed transaction',
    () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            MethodChannelStoreKitPurchaseBridge.channel.name,
            (message) async {
              captured = codec.decodeMethodCall(message);
              return codec.encodeSuccessEnvelope({
                'status': 'verified',
                'productId': 'cc.saidian.report.single',
                'transactionId': '9001',
                'appAccountToken': 'payment-uuid',
                'signedTransactionInfo': 'signed-jws',
              });
            },
          );

      final transaction = await const MethodChannelStoreKitPurchaseBridge()
          .purchase(
            productId: 'cc.saidian.report.single',
            appAccountToken: 'payment-uuid',
          );

      expect(captured?.method, 'purchase');
      expect(captured?.arguments, {
        'productId': 'cc.saidian.report.single',
        'appAccountToken': 'payment-uuid',
      });
      expect(transaction.state, StoreKitPurchaseState.verified);
      expect(transaction.signedTransactionInfo, 'signed-jws');
    },
  );

  test('restore filters incomplete and non-verified transactions', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          MethodChannelStoreKitPurchaseBridge.channel.name,
          (message) async => codec.encodeSuccessEnvelope([
            {
              'status': 'verified',
              'productId': 'cc.saidian.report.single',
              'transactionId': '9001',
              'appAccountToken': 'payment-uuid',
              'signedTransactionInfo': 'signed-jws',
            },
            {'status': 'pending'},
            {
              'status': 'verified',
              'productId': 'cc.saidian.report.single',
              'transactionId': '',
              'appAccountToken': 'payment-uuid',
              'signedTransactionInfo': 'signed-jws',
            },
          ]),
        );

    final restored = await const MethodChannelStoreKitPurchaseBridge()
        .restorePurchases();

    expect(restored, hasLength(1));
    expect(restored.single.transactionId, '9001');
  });

  test('finish forwards only the server-confirmed transaction id', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          MethodChannelStoreKitPurchaseBridge.channel.name,
          (message) async {
            captured = codec.decodeMethodCall(message);
            return codec.encodeSuccessEnvelope(true);
          },
        );

    final finished = await const MethodChannelStoreKitPurchaseBridge().finish(
      '9001',
    );

    expect(finished, isTrue);
    expect(captured?.method, 'finish');
    expect(captured?.arguments, {'transactionId': '9001'});
  });
}
