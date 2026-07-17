# Security

`shitshow` is intended to process sensitive meeting recordings locally.
Its source repository is public and must never contain real meeting artifacts.

## Report a vulnerability

Do not open a public issue for a vulnerability that could expose recordings,
transcripts,
credentials,
private paths,
or managed workspace state.
Contact the KnickKnackLabs maintainers privately through GitHub Security Advisories
or another established private channel.
Include the smallest reproduction that does not disclose real meeting content.

## Accidental sensitive-data exposure

If private data enters a commit,
issue,
pull request,
CI log,
or release artifact:

1. Stop further publication and automation.
1. Notify a maintainer privately.
1. Preserve the relevant commit and run identifiers without reposting the data.
1. Rotate any exposed credentials.
1. Remove the data from every reachable surface and assess whether history rewrite is required.
1. Do not treat deletion from the latest branch as complete remediation.

## Repository boundary

Only synthetic audio and fictional metadata belong in tests and examples.
Real recordings,
transcripts,
prompts,
logs,
meeting names,
credentials,
and private workspace metadata stay outside Git.

Managed local state should default to user-only access.
Path traversal,
symlink escapes,
unsafe ownership,
stale process identifiers,
and concurrent review-state mutation are security boundaries,
not convenience errors.

Recording consent and lawful use are operator responsibilities.
This project does not provide legal advice.
