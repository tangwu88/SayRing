part of '../prototype_pages.dart';

/// Compatibility route for saved notification navigation.
class HealthWarningPage extends StatelessWidget {
  const HealthWarningPage({
    required this.controller,
    this.targetReminderId,
    super.key,
  });
  final AppController controller;
  final String? targetReminderId;

  @override
  Widget build(BuildContext context) => HealthReminderCenterPage(
    controller: controller,
    targetReminderId: targetReminderId,
  );
}
