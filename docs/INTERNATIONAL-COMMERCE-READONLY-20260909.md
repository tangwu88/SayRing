# International catalog: V2 read-only contract and UI

## Baseline and defects

- Date: 2026-09-09. Workspace: `F:/xcodeplace/saydian-app-global`, `main`, baseline `c9faadae517ca40bd8c35b2e37de09ce2e54c345`.
- `git status --short --branch`, `git remote -v`, `git rev-parse HEAD`, `git fetch --prune origin`, `git rev-list --left-right --count HEAD...origin/main`: remote fetch succeeded, ahead/behind `0 0`. Existing domain-switch edits were preserved; no pull, reset or commit was performed by this subtask.
- Read the international handoff, change/test index, latest domain-switch note, retrospective and regression checklist. Server contract was inspected read-only in `F:/xcodeplace/saydian-server-global`; no server files or data were changed.
- P1: `getShopHome` returned the V2 `{banners,categories,featured}` response, while the imported page expected V1 `items/swiper/tabs`, making a populated V2 catalog look empty.
- P1: V2 product, order, address and SKU IDs are UUID strings, but imported methods/pages require integers. The product tap silently returned for a UUID. Synthetic integer maps would hide the contract mismatch and were rejected.
- P1: imported product cards rendered `¥` unconditionally. The inspected V2 product card/SKU currently provides `priceCents`/`salePriceCents` without currency metadata; these are not evidence of accepted international market pricing.
- Protected boundary: server `globalMarkets` declares `commerceEnabled=false`; the international address contract requires ISO country and international phone, unlike the existing domestic province/city integer form. Do not open checkout or silently fill these missing values.

## Changes and expected behavior

- Added a minimal `GlobalCommerceApi` used by actual `AppController` and global shop pages: public products with server keyword/category/page filters, and product details using the original opaque string ID.
- Transport uses canonical V2 literals only; the root task maps them to `/global/api/saydian-app/v2` before strict same-origin validation. No V1 paths or old-domain fallback were added.
- `ShopHomePage` routes the international edition to a separate browse-only catalog. It consumes V2 categories/banner metadata and the full paginated product endpoint instead of treating the twelve featured cards as the entire store. It offers search, category selection, pagination, details and ordinary retry/empty states.
- Search responses are generation-bound immediately when text changes, so late results cannot replace a newer query. Details preserve actual SKU text, gallery and description without executing HTML scripts or external embedded pages.
- All catalog images pass the first-party media policy and use the shared redirect-safe image provider. Unknown third-party/CDN product pictures are not accepted as official watch-face exceptions.
- Missing amount, currency or exponent displays **Price to be confirmed**, never `¥0`. Explicit server currency/exponent controls formatting; no exchange rate, inferred market or CNY default. Real zero remains distinguishable from missing price.
- Three ARB keys have translations in all eight supported languages (including the three Chinese locale resources): pending price, browse-only notice and load-more action. Generated localization files are included.
- Existing integer-ID product, order, address, logistics, cart and transaction methods now explicitly fail with feature-unavailable before networking. Existing create-order/payment gates remain closed. No successful empty response, fabricated ID or write acknowledgement is returned.

## Command-level checks

Toolchain: Flutter/Dart `D:/Dev/Flutter/3.44.9/bin`.

1. `flutter.bat gen-l10n`: succeeded.
2. `dart.bat format lib/services/global_api_client.dart lib/services/app_controller.dart lib/ui/shop_pages.dart lib/ui/global_shop_pages.dart test/global_commerce_api_test.dart test/global_shop_pages_test.dart test/global_shop_media_test.dart`: succeeded, 7 files checked / 5 changed. Parent coordinated the shared-file edit window.
3. `flutter.bat test --no-pub test/global_commerce_api_test.dart test/global_shop_pages_test.dart test/global_shop_media_test.dart`: **17/17 passed** on the initial implementation.
4. `dart.bat analyze` on those same seven Dart files: one informational lint in a new test, missing braces around an `if`; production behavior unaffected. Added braces instead of suppressing the lint.
5. `git diff --check`: passed. Git reported existing Windows LF/CRLF warnings; no whitespace error. Diagnostic attempts using literal PowerShell wildcard paths and the wrong server schema location returned not-found errors; switched to `rg` directory searches and verified `apps/api/prisma/schema.prisma` instead. No files were deleted or overwritten in response.
6. Added readable localized text to the load-more button; repeated `flutter.bat gen-l10n`: succeeded.
7. `dart.bat format lib/ui/global_shop_pages.dart test/global_commerce_api_test.dart`: **2 files / 0 changes**.
8. Repeated targeted `dart.bat analyze`: **No issues found**.
9. Repeated the same three-file Flutter command: **17/17 passed**, approximately 5 seconds test execution. The test binding returns HTTP 400 for attempted allowed image loads; this is fixture behavior, not a live server response. Forbidden sources never produce network image providers.

Coverage: 4 API tests, 11 new Widget tests and 2 updated image-safety tests. Includes actual global entry, UUID detail navigation/return, strict isolated host/path, category/search/pagination, stale search response, retry vs empty, all 16 legacy commerce methods making zero requests, missing currency/amount, true zero USD, JPY exponent 0, KWD exponent 3, 375×812 and 390×844 at text scales 1.0/1.5/2.0, and first-party-only list/HTML media.

## Remaining acceptance — not claimed complete

- The root task owns full dual-timezone suite, overall static checks, final Android builds/install, runtime egress inspection and Git delivery. These 17 host tests do not replace those gates.
- No live registration, account mutation, order, payment, refund, receipt, logistics modification or address write was executed by this subtask.
- International order history/detail, cart and address UI still need explicit opaque-ID/currency/country migration before they can become usable. They currently give unavailable feedback, not working read-only lists. Existing user data has not been migrated or cleared.
- Public product API shape is source-verified, but new-domain isolated catalog contents, image delivery, pricing metadata, translations, inventory ownership and shipping/payment channel acceptance still require the deployed server and true-device joint round. An empty isolated catalog must remain empty; do not copy domestic inventory to populate this screen.
- The server currently does not publish product/SKU currency and exponent; all such prices correctly remain pending. Adding valid market prices is a server contract/operational task, not permission to reinterpret the old cents as a different currency.
- Global catalog descriptions are safe text plus images, not an executable WebView; arbitrary embedded video, scripts and external links are intentionally not enabled.
