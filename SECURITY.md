# Security Policy

## Supported Versions

This is a demo project. Only the latest `main` branch is maintained.

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not** open a public issue.
Instead, report it privately via GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
for this repository.

Please include:

- A description of the issue and its impact
- Steps to reproduce
- Any suggested remediation

We aim to acknowledge reports within a reasonable time frame.

## Scope & Notes

- This project stores demo data in an **in-memory database** and ships no real
  credentials or secrets.
- Do not commit `.env` files or any secrets — they are excluded via
  [.gitignore](.gitignore).
