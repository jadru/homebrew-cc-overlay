# Security Policy

## Supported Releases

Security fixes are applied to the latest released version on the default branch. Older releases may not receive updates.

## Reporting a Vulnerability

Do not open a public issue for credential exposure, token handling, code-signing, notarization, or local file access vulnerabilities.

Enable GitHub private vulnerability reporting for this repository before the next
public release. Until that setting is enabled, do not disclose a vulnerability
in a public issue; contact the repository owner through their GitHub profile and
share only a minimal, non-secret description until a private channel is agreed.

Maintainers should acknowledge a report within three business days, give a
status update within 14 days, and coordinate a fix and disclosure date with the
reporter. Reports must include the affected version, prerequisites, impact, and
a minimal reproduction—never OAuth tokens, Keychain values, `auth.json`
contents, transcripts, or local paths.

## Data Handling

CC-Overlay can read local CLI configuration and transcript data. Contributors must not add telemetry that exports usage history or credentials, and must never write tokens or OAuth response bodies to logs.

The app's crown-jewel data is provider credentials and locally read transcript
metadata. Any change that reads, persists, logs, exports, or sends that data
requires a threat-model note, regression test, and an explicit user-facing
consent or export action. CSV export is local and user-initiated.

## Release Verification

Official GitHub Releases are Developer ID signed, notarized, and stapled. Verify the published SHA-256 checksum and app signature before installing a release. Development builds and artifacts from forks are not official releases.

Release automation pins third-party GitHub Actions to commit SHAs and uses
Dependabot to review action and landing dependency updates monthly.
