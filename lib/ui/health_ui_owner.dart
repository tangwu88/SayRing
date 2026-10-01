import '../services/app_controller.dart';

/// Fences history queries to the stable owner and currently selected exact ring.
/// Expiring tokens are excluded; the edition separates backend environments.
(bool, String?, String?) healthUiOwnerKey(AppController controller) {
  final session = controller.session;
  final memberId = session?.memberId.trim() ?? '';
  final identity = session == null
      ? null
      : memberId.isNotEmpty
      ? 'member:$memberId'
      : 'account:${session.accountKey.trim()}';
  return (
    controller.isGlobalEdition,
    identity,
    (controller.connectedDevice ?? controller.rememberedDevice)?.id,
  );
}
