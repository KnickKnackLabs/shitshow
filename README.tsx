/** @jsxImportSource jsx-md */

import { existsSync, readFileSync, readdirSync, statSync } from "fs";
import { join, resolve } from "path";

import {
  Badge,
  Badges,
  Bold,
  Cell,
  Center,
  Code,
  CodeBlock,
  Details,
  HR,
  Heading,
  Item,
  LineBreak,
  Link,
  List,
  Paragraph,
  Raw,
  Section,
  Sub,
  Table,
  TableHead,
  TableRow,
} from "readme";

const PROJECT = {
  name: "shitshow",
  oneLine: "A local-first workflow for turning private meeting recordings into reviewed records.",
  tagline: "Turn the shitshow into a reviewed record.",
  license: "MIT",
};

const REPO_DIR = resolve(import.meta.dirname);
const TASK_DIR = join(REPO_DIR, ".mise/tasks");
const TEST_DIR = join(REPO_DIR, "test");
const WORKFLOW = join(REPO_DIR, ".github/workflows/test.yml");

interface TaskInfo {
  name: string;
  description: string;
}

function read(path: string): string {
  return readFileSync(path, "utf8");
}

function walkFiles(dir: string, predicate: (path: string) => boolean): string[] {
  if (!existsSync(dir)) return [];

  const results: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkFiles(full, predicate));
    } else if (predicate(full)) {
      results.push(full);
    }
  }
  return results;
}

function discoverTasks(dir = TASK_DIR, prefix = ""): TaskInfo[] {
  if (!existsSync(dir)) return [];

  const tasks: TaskInfo[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith(".")) continue;
    const full = join(dir, entry.name);
    const name = prefix ? `${prefix}:${entry.name}` : entry.name;

    if (entry.isDirectory()) {
      tasks.push(...discoverTasks(full, name));
      continue;
    }

    if ((statSync(full).mode & 0o111) === 0) continue;
    const description = read(full).match(/^#MISE description="(.+)"$/m)?.[1] ?? "";
    tasks.push({ name, description });
  }

  return tasks.sort((a, b) => a.name.localeCompare(b.name));
}

function countBatsTests(): number {
  return walkFiles(TEST_DIR, (path) => path.endsWith(".bats"))
    .map(read)
    .join("\n")
    .match(/@test\s+"/g)?.length ?? 0;
}

function configuredLints(): string[] {
  const miseToml = read(join(REPO_DIR, "mise.toml"));
  const start = miseToml.indexOf("[_.codebase]");
  if (start === -1) return [];

  const lines = miseToml.slice(start).split("\n");
  const block: string[] = [];
  for (const [index, line] of lines.entries()) {
    if (index > 0 && line.startsWith("[")) break;
    block.push(line);
  }

  const list = block.join("\n").match(/lint\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
  return [...list.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

function workflowOses(): string[] {
  if (!existsSync(WORKFLOW)) return [];
  const match = read(WORKFLOW).match(/os:\s*\[([^\]]+)\]/);
  if (!match) return [];
  return match[1].split(",").map((os) => os.trim()).filter(Boolean);
}

const tasks = discoverTasks();
const testCount = countBatsTests();
const lints = configuredLints();
const oses = workflowOses();

const readme = (
  <>
    <Center>
      <Heading level={1}>{PROJECT.name}</Heading>
      <Paragraph><Bold>{PROJECT.oneLine}</Bold></Paragraph>
      <Paragraph>{PROJECT.tagline}</Paragraph>
      <Badges>
        <Badge label="status" value="incubating" color="orange" />
        <Badge label="tests" value={`${testCount}`} color="brightgreen" href="test/" />
        <Badge label="lints" value={`${lints.length}`} color="blue" />
        <Badge label="CI" value={workflowOses().join(" + ") || "pending"} color="4EAA25" />
        <Badge label="License" value={PROJECT.license} color="blue" href="LICENSE" />
      </Badges>
    </Center>

    <LineBreak />

    <Section title="What this is">
      <Paragraph>
        <Code>shitshow</Code>
        {" is an incubating KnickKnackLabs tool for long-form recordings that deserve deliberate review instead of one-shot summarization."}
      </Paragraph>
      <Paragraph>
        {"The intended first release ingests a local audio source into a private managed workspace, verifies its checksum, transcribes resumable chunks locally, reports progress, and advances review state only after a human and agent have actually reviewed the material."}
      </Paragraph>
      <Paragraph>
        {"It does not claim that raw ASR output is authoritative meeting minutes, and it does not generate legal, medical, financial, or other domain conclusions without human review."}
      </Paragraph>
    </Section>

    <Section title="Current status">
      <Paragraph>
        {"The repository currently contains only the maintained KKL skeleton and its public safety boundary. Product implementation will arrive through reviewed pull requests."}
      </Paragraph>
      <Paragraph>
        {"The workflow grew from private internal dogfood, but this repository starts with fresh, sanitized history. No private meeting artifacts or personal paths were imported."}
      </Paragraph>
    </Section>

    <Section title="Tool boundaries">
      <Table>
        <TableHead>
          <Cell>Tool</Cell>
          <Cell>Owns</Cell>
        </TableHead>
        <TableRow><Cell><Code>voice</Code></Cell><Cell>Microphone capture and short voice-capture artifacts</Cell></TableRow>
        <TableRow><Cell><Code>monkeys</Code></Cell><Cell>Local speech-to-text engines</Cell></TableRow>
        <TableRow><Cell><Code>shitshow</Code></Cell><Cell>Private meeting workspace, resumable transcription, and explicit review state</Cell></TableRow>
        <TableRow><Cell>Domain notes</Cell><Cell>Approved conclusions and durable work products</Cell></TableRow>
        <TableRow><Cell><Code>blobs</Code></Cell><Cell>Storage transport when an operator explicitly chooses it</Cell></TableRow>
      </Table>
    </Section>

    <Section title="Privacy boundary">
      <List>
        <Item>Never commit recordings, transcripts, prompts, logs, credentials, meeting names, or private workspace metadata.</Item>
        <Item>Use synthetic audio and fictional metadata in tests and documentation.</Item>
        <Item>Default managed state to private local permissions and reject unsafe path or symlink boundaries.</Item>
        <Item>Keep upload, archival, and destructive storage operations outside the initial product surface.</Item>
        <Item>Recording consent and lawful use remain operator responsibilities; this tool does not provide legal advice.</Item>
      </List>
      <Paragraph>
        {"See "}<Link href="SECURITY.md">SECURITY.md</Link>{" before reporting a vulnerability or handling accidental sensitive-data exposure."}
      </Paragraph>
    </Section>

    <Section title="Development">
      <CodeBlock lang="bash">{`gh repo clone KnickKnackLabs/shitshow
cd shitshow
mise trust
mise install
mise run test
mise run doctor`}</CodeBlock>
      <Paragraph>
        {"Edit "}<Code>README.tsx</Code>{", then run "}<Code>readme build</Code>{". Do not edit generated "}<Code>README.md</Code>{" directly."}
      </Paragraph>
    </Section>

    <Section title="Tasks">
      <Table>
        <TableHead><Cell>Task</Cell><Cell>Description</Cell></TableHead>
        {tasks.map((task) => (
          <TableRow><Cell><Code>{`mise run ${task.name}`}</Code></Cell><Cell>{task.description}</Cell></TableRow>
        ))}
      </Table>
    </Section>

    <Details summary="Current convention checks">
      <Paragraph>
        {"The repository asks "}<Link href="https://github.com/KnickKnackLabs/codebase">codebase</Link>{" to run these checks:"}
      </Paragraph>
      <CodeBlock>{lints.join("\n")}</CodeBlock>
    </Details>

    <Section title="Validation">
      <CodeBlock lang="bash">{`mise run test
codebase lint "$PWD"
readme build --check
git diff --check`}</CodeBlock>
      <Paragraph>
        {"The bootstrap currently has "}<Bold>{`${testCount} tests`}</Bold>{", "}<Bold>{`${tasks.length} public tasks`}</Bold>{", and hosted validation on "}<Bold>{oses.join(" and ")}</Bold>{"."}
      </Paragraph>
    </Section>

    <Center>
      <HR />
      <Sub>
        {"Generated from "}<Code>README.tsx</Code>{" with "}<Link href="https://github.com/KnickKnackLabs/readme">KnickKnackLabs/readme</Link>{"."}
        <Raw>{"<br />"}</Raw>
        {"A reviewed record is what remains after the shitshow."}
      </Sub>
    </Center>
  </>
);

console.log(readme);
