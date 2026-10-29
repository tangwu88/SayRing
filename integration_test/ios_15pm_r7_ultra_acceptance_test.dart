import 'ios_read_only_page_walkthrough_test.dart' as walkthrough;
import 'ios_xr_r7pro_release_acceptance_test.dart' as owned;
import 'ios_health_reading_reminder_ui_test.dart' as reading;
import 'ios_xr_secondary_pages_test.dart' as secondary;
import 'ios_vibrating_settings_test.dart' as settings;

/// Real existing owner only. The private build must select R7 Ultra explicitly.
/// Every physical action is guarded again by the exact remembered target/model.
/// Use the preserving Profile runner and restore production main afterward.
void main() {
  walkthrough.main();
  settings.main();
  owned.registerOwnedRingReleaseAcceptance(requiredModel: 'R7ULTRA');
  reading.registerReadingReminderUiAcceptance(requiredModel: 'R7ULTRA');
  secondary.main();
}
