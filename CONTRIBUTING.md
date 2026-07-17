# Contributing

`shitshow` turns private long-form recordings into resumable,
reviewable records.
The repository is public;
private meeting data is not.

Read this file before editing code,
tests,
documentation,
or workflow configuration.

## Product boundary

The initial shared workflow will own:

- checksum-safe ingestion of an explicit local audio source;
- private managed meeting workspaces;
- resumable local chunk transcription through `monkeys hear`;
- human-readable and machine-readable status;
- review output that does not move the cursor;
- explicit cursor advancement after collaborative review.

It will not initially own cloud storage,
B2 version management,
automatic authoritative minutes,
or domain-specific legal,
medical,
or financial conclusions.

`voice` owns recording.
`monkeys` owns transcription engines.
`blobs` owns storage transport.
The repository or note system for the relevant domain owns approved conclusions.

## Privacy and safety

Never commit real recordings,
transcripts,
meeting names,
prompts,
logs,
credentials,
private paths,
or copied workspace metadata.
Use synthetic audio and fictional metadata in every fixture and example.

New managed-state behavior must preserve private permissions,
reject unsafe symlink and path boundaries,
and use atomic writes where interruption could corrupt state.
Background-job control must verify process identity before signaling a PID.
Review-state mutation must be explicit,
locked,
and auditable.

Upload and destructive operations require a separate design and review.
Recording consent and lawful use remain operator responsibilities.
See `SECURITY.md` for vulnerability and accidental-exposure handling.

## Structure

```text
shitshow/
├── mise.toml              # Tools, settings, and codebase lint config
├── README.tsx             # Source for generated README.md
├── README.md              # Generated; do not edit directly
├── CONTRIBUTING.md        # Repo-entry orientation
├── SECURITY.md            # Security and sensitive-data reporting
├── .mise/tasks/           # Thin public task entry points
├── lib/                   # Sourced implementation modules (`*.sh`)
├── libexec/               # Internal executables, not public tasks
└── test/                  # BATS tests using synthetic fixtures
```

Choose implementation modules by independently changing pipeline concepts,
such as workspace state,
transcription jobs,
and review state.
Keep public task files thin.
Do not collect unrelated helpers into a generic utility file.

## Local setup

```bash
mise trust
mise install
mise run test
mise run doctor
```

Install the optional clone-local pre-commit hook with:

```bash
codebase pre-commit
```

## README workflow

Edit `README.tsx`,
then regenerate and verify the checked-in output:

```bash
readme build
readme build --check
```

## Tests

BATS tests must call public tasks through `mise run`.
Do not invoke `.mise/tasks/*` directly from tests.
Fixtures must remain synthetic and public-safe.

Add adversarial coverage for permissions,
symlinks,
checksum failure,
ASR failure and resume,
stale process state,
concurrent review updates,
and interrupted atomic writes as those surfaces are implemented.

## Validation before review

```bash
mise run test
codebase lint "$PWD"
readme build --check
git diff --check
```

Use a branch and pull request for product implementation.
Keep skeleton changes separate from behavior extraction when possible.
