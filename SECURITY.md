# Security policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub: [report a vulnerability](https://github.com/JohanLindvall/regtend/security/advisories/new). Please do not open a public issue, pull request or discussion for a suspected vulnerability.

Include the Regtend version (`regtend --version`), the registry (ACR or GHCR), the command and rule file involved, and the steps to reproduce. Leave out credentials, tokens and private registry content. The report and its follow-up stay private until a fix is released.

## Supported versions

Only the [latest release](https://github.com/JohanLindvall/regtend/releases/latest) receives fixes. Every change to `main` is released, so a fix ships as a new release; upgrade with the [install script](README.md#install).

## Scope

Regtend holds registry credentials and deletes images, so these count as vulnerabilities, for example:

- deleting, or unlocking, anything the rules and the README say must be kept;
- sending Azure or GitHub credentials to a host other than the registry's own API and token endpoints;
- path traversal or other unsafe file handling with registry-supplied names, digests or cache content;
- `scripts/download.sh` installing anything other than the release binary that matches the release's checksums.
