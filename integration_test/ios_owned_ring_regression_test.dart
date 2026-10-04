import 'ios_hr01_monitoring_test.dart' as monitoring;
import 'ios_read_only_page_walkthrough_test.dart' as walkthrough;

/// Run serially in one verified Profile binary, keeping the existing owner.
/// The monitoring test requires the already-bound physical HR01; no scanning,
/// account replacement, mock readings or uninstall fallback is allowed.
void main() {
  walkthrough.main();
  monitoring.main();
}
