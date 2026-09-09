# International legal entry repair — 2026-09-10

## Baseline, defect and scope

- Branch `main`; `git fetch --prune origin` succeeded. `HEAD` and `origin/main` both `c9faadae517ca40bd8c35b2e37de09ce2e54c345`. Preserved the joint-QA dirty working tree; no reset, merge, commit or deployment by this subtask.
- Read `AGENTS.md`, international handoff, latest joint-QA record and the existing retrospective/regression rules. Subsequent coworkers must update and read these records before editing.
- P1 reproduction: **My → Account settings → Privacy policy** requested ordinary international `content/articles/3`, not the published legal document. About terms/privacy still used the legacy single-article reader. A mock server with valid published legal content could not display it through these entries.
- The legal API adapter also accepted only the canonical controller prefix. A capability response containing the deployed `/global/api/saydian-app/v2/content/legal/...` path was rejected locally.
- Source contract checked read-only against the independent server workspace: `apps/api/src/auth/global-legal.ts` emits the reviewed bundle's version, locale and legal references; `apps/api/src/content/content.service.ts` returns `documentType`, `version`, `locale`, `reviewed`, `contentHtml`. This is contract evidence, not proof that the global service is deployed or that legal text has been reviewed in production.

## Minimal implementation

- Added `lib/ui/global_legal_page.dart`, reused by login/register, account privacy, and both About legal entries. Domestic-only compatibility remains separate.
- Each opening/retry obtains `auth/capabilities`, requires a nonempty `consentVersion` and its exact document reference, and reads the declared version/locale. Returned type, version, locale and `reviewed=true` must match; empty or non-string content fails closed.
- Rendered selectable, scrollable plain text from the actual returned HTML, preserving paragraph breaks and removing script/style/noscript nodes. No embedded remote images, links or scripts are fetched. The actual version and document language are shown, including English fallback supplied by the server.
- Loading/error/retry and normal back navigation are explicit. There is no fabricated/local agreement fallback and opening a document does not record consent. Login rereads capabilities and clears the old consent tick after returning, so an old acceptance does not silently survive a version refresh.
- `GlobalSaydianApiClient.getGlobalLegalDocument` alone now accepts canonical or deployed legal relative paths and maps both to the isolated origin. Absolute/external URLs, V1/ordinary article paths, traversal, fragments, missing/duplicate versions, unknown locale and extra query keys are denied before sending. Existing transport redirect protection is unchanged.
- International About no longer requests the legacy article for its introduction; existing safe local brand introduction remains an introduction, not a fetched legal document.
- Files: the new legal page; `global_auth_page.dart`; only relevant entry hunks in `pages.dart`/`prototype_pages.dart`; only the legal method in `global_api_client.dart`; `test/global_legal_page_test.dart`. Other agents' image/API changes are preserved. No native changes, device writes, account writes, consent records or backend edits were made in this repair.

## Commands, failures and corrections

Commands run from `F:/xcodeplace/saydian-app-global` using `D:/Dev/Flutter/3.44.9/bin`:

1. `flutter test --no-pub test/global_legal_page_test.dart --reporter expanded` before repair: first failed on an incorrect test label (`Privacy agreement` versus translated `Privacy policy`). Corrected the finder to the actual privacy icon, without changing production text.
2. The same command before repair then reproduced the real failure: ordinary article request returned 404; the published legal content did not appear. This failure was not a pump/timing issue.
3. After repair and expanded cases, the same command: **32 passed / 1 failed**. The 404-capabilities case increased the lazy list height, so `ensureVisible` could not find the unbuilt register toggle. Used `scrollUntilVisible` as the existing auth tests do; no production availability gate was loosened.
4. `dart format lib/ui/global_legal_page.dart test/global_legal_page_test.dart lib/ui/global_auth_page.dart`: 3 files formatted. Did not run formatting on the large shared `pages.dart`/`prototype_pages.dart` or the API file.
5. Focused `dart analyze lib/ui/global_legal_page.dart lib/ui/global_auth_page.dart lib/ui/prototype_pages.dart lib/ui/pages.dart lib/services/global_api_client.dart test/global_legal_page_test.dart`: initially 2 brace-style infos in the new test; fixed both. Final rerun: **No issues found**.
6. `flutter test --no-pub test/global_legal_page_test.dart test/global_auth_page_test.dart test/global_api_test.dart test/global_network_boundary_test.dart test/prototype_coverage_test.dart --reporter expanded`: first **97/97 passed**. Added explicit capabilities-404 legal-page retry coverage and switched About's selector from article numbers to document types; final rerun **98/98 passed**.
7. Final formatting `dart format test/global_legal_page_test.dart`: 0 changes. Earlier post-format check of the new page/test also 0 changes. `git diff --check` for scoped files and the coverage document: passed (only repository CRLF conversion notices).
8. Read-only path discovery initially tried nonexistent `lib/models/global_account_models.dart`, `docs/DEVELOPMENT-RETROSPECTIVE.md` and a server `src` root, plus unsupported PowerShell wildcard path arguments to `rg`. Corrected to `lib/domain/global_account.dart`, the linked retrospective and independent server `apps/api/src` paths; no speculative sources were created.

### Added test coverage: 34 cases

- Five real entry Widget flows: account privacy; About terms/privacy; login terms/privacy. Exact `auth/capabilities → content/legal/{type}` request path/query, first-party origin, disabled redirects, published body and back navigation verified.
- Twelve failed-reference/document/provider states recover by retry; missing capability/version/path never substitutes a local document, and invalid references send no legal fetch.
- Missing capabilities leaves the registration submit and consent checkbox disabled; no verification/register request is emitted.
- 375×812 with 2× text and long paragraphs remains scrollable without overflow.
- Two canonical/deployed legal-reference mappings succeed on the same isolated new origin.
- Thirteen unsafe/unversioned legal references are rejected with zero HTTP sends.

## Remaining acceptance boundary

- **Not final-phone accepted.** The connected W9 and previous Android package are not evidence for this new legal UI. Root owns final full-suite/both-timezone runs, builds, installation and live entry verification.
- Real capabilities/documents, legal publication/review/locale and registration consent persistence must be confirmed with the isolated server. If capabilities is 404, registration remains unavailable rather than bypassing consent.
- The records and [80-operation joint coverage matrix](INTERNATIONAL-JOINT-COVERAGE-20260910.md) should be committed with source by the root task. No raw log, screenshot, account, contact or health data is included.
