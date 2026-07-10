# Security Policy

## Supported Releases

Security fixes are applied to the latest released version on the default branch. Older releases may not receive updates.

## Reporting a Vulnerability

Do not open a public issue for credential exposure, token handling, code-signing, notarization, or local file access vulnerabilities.

Private vulnerability reporting is not configured for this repository yet. Do not disclose sensitive details in a public issue. Contact the maintainer through the repository owner's GitHub profile and include a minimal reproduction, impact, and affected version.

## Data Handling

CC-Overlay can read local CLI configuration and transcript data. Contributors must not add telemetry that exports usage history or credentials, and must never write tokens or OAuth response bodies to logs.

## Release Verification

Official GitHub Releases are Developer ID signed, notarized, and stapled. Verify the published SHA-256 checksum and app signature before installing a release. Development builds and artifacts from forks are not official releases.
