# Security Policy

## Supported versions

Security fixes are applied to the latest version on the `main` branch.

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability or exposed
credential. Use GitHub's **Security → Report a vulnerability** flow for this
repository so the report and follow-up remain private.

Include the affected version or commit, reproduction steps, impact, and any
suggested mitigation. Please avoid accessing data that is not your own or
testing against systems without authorization.

## Local data and optional AI

The core app runs locally. Learner code, lessons, and progress are stored on
the Mac. The optional remote AI provider is disabled by default and runs only
after the user enables it and requests help.

API-mode credentials are currently stored in local app preferences rather than
macOS Keychain. Prefer the local CLI provider, use development-scoped API keys,
and rotate a key immediately if it may have been exposed.
