import 'ios_read_only_page_walkthrough_test.dart' as walkthrough;
import 'ios_xr_r7pro_release_acceptance_test.dart' as owned;
import 'ios_health_reading_reminder_ui_test.dart' as reading;
import 'ios_xr_secondary_pages_test.dart' as secondary;

/// Private probe must explicitly select R21. Existing owner/binding/data only;
/// no reset, fabricated samples or vibration action on this non-vibrating model.
void main() {
  walkthrough.main();
  owned.registerOwnedRingReleaseAcceptance(requiredModel: 'R21');
  reading.registerReadingReminderUiAcceptance(
    requiredModel: 'R21',
    requireVibration: false,
  );
  secondary.main();
}
