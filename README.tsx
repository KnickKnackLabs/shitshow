/** @jsxImportSource jsx-md */

import { existsSync, readFileSync, readdirSync } from "fs";
import { join, resolve } from "path";

import {
  Badge,
  Badges,
  Center,
  Code,
  CodeBlock,
  Details,
  Heading,
  HR,
  Item,
  Link,
  List,
  Paragraph,
  Raw,
  Section,
  Sub,
} from "readme";

const REPO_DIR = resolve(import.meta.dirname);
const TEST_DIR = join(REPO_DIR, "test");
const WORKFLOW = join(REPO_DIR, ".github/workflows/test.yml");

function read(path: string): string {
  return readFileSync(path, "utf8");
}

function countBatsTests(dir = TEST_DIR): number {
  if (!existsSync(dir)) return 0;

  let count = 0;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      count += countBatsTests(path);
    } else if (path.endsWith(".bats")) {
      count += read(path).match(/@test\s+"/g)?.length ?? 0;
    }
  }
  return count;
}

function configuredLintCount(): number {
  const miseToml = read(join(REPO_DIR, "mise.toml"));
  const block = miseToml.match(/\[_\.codebase\][\s\S]*?lint\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
  return [...block.matchAll(/"([^"]+)"/g)].length;
}

function workflowOses(): string {
  if (!existsSync(WORKFLOW)) return "pending";
  const value = read(WORKFLOW).match(/os:\s*\[([^\]]+)\]/)?.[1];
  return value?.split(",").map((os) => os.trim()).filter(Boolean).join(" + ") || "pending";
}

const testCount = countBatsTests();
const lintCount = configuredLintCount();

const readme = (
  <>
    <Center>
      <Raw>{`<img src="assets/jeff.webp" alt="Nicolas Cage laughing on a toilet in a decrepit restroom" width="800">\n\n`}</Raw>
      <Heading level={1}>shitshow</Heading>
      <Badges>
        <Badge label="status" value="incubating" color="orange" />
        <Badge label="tests" value={`${testCount}`} color="brightgreen" href="test/" />
        <Badge label="lints" value={`${lintCount}`} color="blue" />
        <Badge label="CI" value={workflowOses()} color="4EAA25" />
        <Badge label="license" value="MIT" color="blue" href="LICENSE" />
      </Badges>
    </Center>

    <Paragraph>
      Long recordings are copied into private,
      checksum-bound workspaces and transcribed locally in resumable chunks.
      Transcription state and review state are separate:
      completed ASR means text exists;
      cursor advancement means someone checked it.
    </Paragraph>

    <Section title="Install">
      <CodeBlock lang="bash">{`gh repo clone KnickKnackLabs/shitshow
cd shitshow
mise trust
mise install`}</CodeBlock>
    </Section>

    <Section title="Run">
      <CodeBlock lang="bash">{`result="$(mise run ingest recording.wav --name "Fictional planning call" --json)"
meeting_id="$(jq -r .meeting_id <<<"$result")"

mise run transcribe:start "$meeting_id"
mise run status "$meeting_id"
mise run review "$meeting_id"
mise run review:advance "$meeting_id"`}</CodeBlock>
    </Section>

    <Details summary="Operational notes">
      <List>
        <Item>Managed meetings default to <Code>{"${XDG_DATA_HOME:-$HOME/.local/share}/shitshow/meetings"}</Code>.</Item>
        <Item>Directories use <Code>0700</Code>; files use <Code>0600</Code>; ingestion verifies SHA-256.</Item>
        <Item><Code>review</Code> is read-only. Only <Code>review:advance</Code> moves the audited cursor.</Item>
        <Item><Code>status --json</Code> exposes the same state to other programs.</Item>
        <Item>Never commit recordings, transcripts, prompts, logs, credentials, meeting names, or private workspace metadata.</Item>
        <Item>Recording consent and lawful use remain the operator's responsibility.</Item>
      </List>
    </Details>

    <Section title="Documentation">
      <Paragraph>
        Public tasks include examples in <Code>--help</Code>.
        See <Link href="CONTRIBUTING.md">CONTRIBUTING.md</Link> for the implementation and validation contract,
        and <Link href="SECURITY.md">SECURITY.md</Link> for private-state and disclosure handling.
      </Paragraph>
    </Section>

    <Center>
      <HR />
      <Sub>
        Generated with <Link href="https://github.com/KnickKnackLabs/readme">KnickKnackLabs/readme</Link>.
      </Sub>
    </Center>
  </>
);

console.log(readme);
