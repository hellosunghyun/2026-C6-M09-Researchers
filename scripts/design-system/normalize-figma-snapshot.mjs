import { createHash } from "node:crypto";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// 공식 Figma 도구의 읽기 전용 응답을 비교 가능한 구조로 보관합니다.
// 전체 원본 .fig나 이미지가 포함된 원본 사본을 대체하지 않습니다.
const [inputDirectory, capturedDate, outputPath] = process.argv.slice(2);
if (!inputDirectory || !/^\d{4}-\d{2}-\d{2}$/.test(capturedDate ?? "")) {
  throw new Error(
    "Usage: node normalize-figma-snapshot.mjs <MCP 응답 폴더> <YYYY-MM-DD> [출력 JSON]",
  );
}

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const input = resolve(inputDirectory);
const output = outputPath
  ? resolve(outputPath)
  : join(repository, "docs/design-system-figma-baseline.json");
const tokenArchive = JSON.parse(await readFile(join(
  repository,
  "Packages/ResearchersModules/Sources/LabcordDesignSystem/Recources/DesignTokens.json",
), "utf8"));

function parseToolResponse(contents, name) {
  const response = JSON.parse(contents);
  if (response.isError) throw new Error(`Figma 응답 오류: ${name}`);
  const text = response.content?.find((item) => item.type === "text")?.text;
  if (!text) throw new Error(`JSON 본문 누락: ${name}`);
  return JSON.parse(text);
}

const files = (await readdir(input)).filter((name) =>
  /^(?:(live-.+|pattern-\d+-\d+)-variants|component-\d+-\d+)\.json$/.test(name)
).sort();
const components = [];
const hashes = {};
for (const name of files) {
  const contents = await readFile(join(input, name), "utf8");
  const component = parseToolResponse(contents, name);
  if (!component.id || !component.variants?.length || !Array.isArray(component.styles)) {
    throw new Error(`컴포넌트 응답 형식 확인 필요: ${name}`);
  }
  hashes[name] = createHash("sha256").update(contents).digest("hex");
  components.push(component);
}
components.sort((left, right) => left.id.localeCompare(right.id, "en", { numeric: true }));
if (new Set(components.map((component) => component.id)).size !== components.length) {
  throw new Error("컴포넌트 ID 중복");
}

const snapshot = {
  schemaVersion: 1,
  source: {
    fileKey: "v6cxQ2I6zURWYQaG5pnuBL",
    pageId: "697:9676",
    capturedDate,
    originalArchiveSHA256: tokenArchive.source.sha256,
    note: "layout와 적용 typography 관찰값. fills.color/opacity는 raw fallback이므로 실제 색상은 bound variable ID와 소비 노드의 mode로 해석합니다.",
  },
  coverage: {
    componentCount: components.length,
    variantsIncludingStandalone: components.reduce((sum, item) => sum + item.variants.length, 0),
    icons: {
      componentId: "711:11329",
      count: (await readdir(join(repository, "scripts/design-system/icon-source")))
        .filter((name) => name.endsWith(".svg")).length,
      source: "scripts/design-system/icon-source",
    },
  },
  responseSHA256: hashes,
  components,
};
await writeFile(output, `${JSON.stringify(snapshot, null, 2)}\n`);
console.log(`Saved ${components.length} components to ${output}`);
