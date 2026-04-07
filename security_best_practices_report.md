# Security Best Practices Report

## Executive Summary
This project is a Flutter client application (Dart) with Android/iOS/Web targets. I did not find obvious remote-code-execution or direct secret-exposure vulnerabilities in the current codebase. The largest practical risks are platform/web hardening gaps (missing CSP on web, default Android backup behavior), unbounded network calls without timeouts, and potentially verbose runtime logging.

Because this skill's built-in reference set does not include Dart/Flutter-specific guidance files, this review combines available frontend web guidance with Flutter/mobile security best practices.

---

## Critical Findings
No critical findings identified.

---

## High Findings

### [SEC-001] Missing Content Security Policy for Flutter Web entrypoint
- Severity: High
- Location: `web/index.html:44`, `web/index.html:48`
- Evidence:
  - Inline script is present:
    - `web/index.html:44` starts `<script>`
    - `web/index.html:48` runs `_flutter.loader.load(...)`
  - No CSP meta/header declaration is present in `web/index.html`.
- Impact: If any HTML/script injection bug is introduced elsewhere (or a third-party script path is compromised), missing CSP significantly increases XSS blast radius.
- Fix:
  1. Serve a CSP header from hosting/CDN (preferred) for web builds.
  2. Avoid broad unsafe directives; keep script sources tightly scoped.
  3. If inline bootstrap script must remain, move to hashed/nonce policy where hosting supports it.
- Mitigation:
  - Add strict input/output handling in web-facing code paths and avoid future inline script additions.
- False positive notes:
  - CSP may be configured outside repo (reverse proxy/CDN). Verify runtime response headers in deployed environments.

---

## Medium Findings

### [SEC-002] Android backup hardening not explicitly configured
- Severity: Medium
- Location: `android/app/src/main/AndroidManifest.xml:2-5`
- Evidence:
  - `<application ...>` does not set `android:allowBackup` or backup-related restrictions.
- Impact: App-private data (including SharedPreferences content) may be included in device backups depending on OS/user configuration, which can increase local data exposure risk.
- Fix:
  1. Set `android:allowBackup="false"` unless you explicitly need backups.
  2. If backups are required, define backup rules explicitly and exclude sensitive entries.
- Mitigation:
  - Avoid storing anything sensitive in SharedPreferences regardless of backup policy.

### [SEC-003] Network requests have no timeout or cancellation guard
- Severity: Medium
- Location: `lib/services/api_service.dart:56`, `lib/services/api_service.dart:110`
- Evidence:
  - `client.get(...)` is called without `.timeout(...)` in both API paths.
- Impact: Unbounded network waits can be abused by hostile/intermittent networks to freeze user flows and create denial-of-service style reliability failures.
- Fix:
  1. Add explicit timeouts for all HTTP calls.
  2. Differentiate timeout exceptions from other failures for safer UX fallback behavior.
- Mitigation:
  - Consider retry strategy with bounded attempts and jitter.

### [SEC-004] Verbose error logging may leak operational details in production builds
- Severity: Medium
- Location: `lib/services/api_service.dart:43-47`, `lib/services/api_service.dart:68-72`, `lib/services/api_service.dart:92-96`, `lib/services/api_service.dart:132-136`, `lib/main.dart:156`, `lib/main.dart:539`
- Evidence:
  - Logs include exception objects and stack traces in runtime paths.
- Impact: On compromised/debuggable devices or centralized log sinks, detailed traces can expose internal behavior and make exploit development easier.
- Fix:
  1. Gate verbose logs behind debug mode/build flavor.
  2. Redact stack traces and response details in production telemetry.
- Mitigation:
  - Standardize a `safeLog` helper with severity + redaction policy.

---

## Low Findings

### [SEC-005] Shared screenshot file is created in temp storage and not removed after share
- Severity: Low
- Location: `lib/main.dart:147-153`
- Evidence:
  - A temporary image file is written and shared, but no cleanup follows.
- Impact: Sensitive-on-screen user context could persist longer than necessary in temporary storage.
- Fix:
  1. Delete temp file after successful share when platform behavior allows.
  2. Consider periodic temp cleanup for generated artifacts.

### [SEC-006] Favorites are stored as plaintext in SharedPreferences
- Severity: Low
- Location: `lib/main.dart:284-299`
- Evidence:
  - Favorites list is JSON-encoded into `SharedPreferences` without encryption.
- Impact: Local data can be read on rooted/jailbroken/debuggable devices or through backups.
- Fix:
  1. If future favorites include sensitive metadata, move to encrypted local storage.
  2. Keep payload minimal and avoid storing data not needed offline.
- False positive notes:
  - Current favorites look non-sensitive (country/year selections), so this is preventive hardening.

---

## Informational Notes

### [SEC-007] API host pinning is not implemented
- Severity: Info
- Location: `lib/services/api_service.dart:9`
- Evidence:
  - Requests rely on default TLS validation only.
- Guidance:
  - For higher assurance threat models, consider certificate/public-key pinning with operational rotation planning.

### [SEC-008] Skill coverage gap for Dart/Flutter references
- Severity: Info
- Evidence:
  - `security-best-practices` references include Python/JavaScript/Go guidance, but no Dart/Flutter file.
- Guidance:
  - Add a Dart/Flutter security reference document to this skill for more repeatable audits.

---

## Recommended Next Actions
1. Add and validate CSP in deployed web environment (highest priority).
2. Harden Android manifest backup settings.
3. Add HTTP timeouts and controlled retry behavior in `ApiService`.
4. Introduce production-safe logging policy (redaction + debug-only stack traces).
5. Optionally clean up temporary shared files and evaluate encrypted storage for future sensitive local data.
