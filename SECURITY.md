# Security Policy

## Supported Versions

This project has no versioned release, and thus only the latest commit on the main-branch and it's currently
deployed live instances are supported.

| Version | Supported          |
| ------- | ------------------ |
| 'main'   | :white_check_mark: |
| older commit/forks   | :x:                |

## Scope

### In scope - do report

- Vulnerabilities that let someone affect other participants or the shared infrastructure, for example:
  - escaping the application container or reaching the underlying k3s node/cluster
  - accessing or modifying other users' or teams' data or progress
  - denial-of-service that takes the instance down for everyone
- Leaked real secrets in the repository or its history (API keys, tokens or credentials that are not part of the exercise)
- Weaknesses in the CI/CD pipeline that could allow tampering with the code or deployment
- Vulnerable dependencies listed in 'requirements.txt'

### Out of scope - don't report

- Missing security headers or best-practice recommendations with no practical exploit
- Third-party issues entirely out of our control.

## Reporting a vulnerability

**Do not open public issues or pull requests for security vulnerabilities.**

When reporting, you can do so privately using Github's private vulnerability reporting:

1. Go to the **Security & quality** tab of this repository.
2. Click **Report a vulnerability**.
3. Fill in the form.


[I would also recommend reading the Github docs on the matter.](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately)

### What to include

To help reproduce and fix an issue quickly, please include the following in your report:

- A short description of the vulnerability and its impact.
- The affected component (endpoint, file path or workflow)
- Step-by-step instruction for reproducing
- Suggested fixes or mitigation
