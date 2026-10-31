#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const repositoryRoot = path.resolve(__dirname, "../..");
const sourcePath = path.join(
    repositoryRoot,
    "Packages/ResearchersModules/Sources/LabcordDesignSystem/Recources/DesignTokens.json"
);
const outputPath = path.join(
    repositoryRoot,
    "Packages/ResearchersModules/Sources/LabcordDesignSystem/Foundation/ColorTokens.swift"
);

function camelCase(name) {
    const parts = name.split(/[^A-Za-z0-9]+/).filter(Boolean);
    return parts
        .map((part, index) => {
            const capitalized = part[0].toUpperCase() + part.slice(1);
            return index === 0
                ? capitalized[0].toLowerCase() + capitalized.slice(1)
                : capitalized;
        })
        .join("");
}

function floatLiteral(value) {
    const literal = String(Number(Number(value).toPrecision(9)));
    if (Math.fround(Number(literal)) !== Math.fround(value)) {
        throw new Error(`Cannot preserve Float32 value ${value}`);
    }
    return literal;
}

function rgbLiteral(color) {
    const components = [color.r, color.g, color.b];
    const bytes = components.map((value) => Math.round(value * 255));
    for (let index = 0; index < components.length; index += 1) {
        if (Math.fround(bytes[index] / 255) !== Math.fround(components[index])) {
            throw new Error(`Cannot preserve RGB Float32 value ${components[index]}`);
        }
    }
    const hex = bytes
        .map((value) => value.toString(16).padStart(2, "0"))
        .join("")
        .toUpperCase();
    return `0x${hex}`;
}

function colorLiteral(color) {
    return `.init(${rgbLiteral(color)}, ${floatLiteral(color.a)})`;
}

function validateFoundationGraph(source) {
    const variables = source.variables.filter((variable) => !variable.compatibilityOnly);
    if (variables.length !== source.source.currentFoundation.canonicalVariableCount) {
        throw new Error("Final Foundation canonical variable count does not match its source");
    }

    const byID = new Map();
    const names = new Set();
    const collections = new Map(source.collections.map((collection) => [collection.id, collection]));
    for (const variable of variables) {
        const name = `${variable.set.id}/${variable.name}`;
        if (byID.has(variable.id) || names.has(name)) {
            throw new Error(`Duplicate Foundation variable: ${variable.id} (${variable.name})`);
        }
        byID.set(variable.id, variable);
        names.add(name);

        const collection = collections.get(variable.set.id);
        if (!collection || variable.entries.length !== collection.modes.length) {
            throw new Error(`Foundation variable has incomplete collection modes: ${variable.id}`);
        }
        const modeIDs = new Set();
        for (const entry of variable.entries) {
            if (modeIDs.has(entry.modeId) || !collection.modes.some(
                (mode) => mode.id === entry.modeId && mode.name === entry.modeName
            )) {
                throw new Error(`Foundation variable has invalid mode metadata: ${variable.id}`);
            }
            modeIDs.add(entry.modeId);
        }
    }

    function resolve(id, modeName, path = []) {
        if (path.includes(id)) {
            throw new Error(`Cyclic Foundation alias: ${path.concat(id).join(" -> ")}`);
        }
        const variable = byID.get(id);
        if (!variable) {
            throw new Error(`Foundation alias target is missing: ${id}`);
        }
        const entry = variable.entries.find((candidate) => candidate.modeName === modeName)
            ?? (variable.entries.length === 1 ? variable.entries[0] : undefined);
        if (!entry) {
            throw new Error(`Foundation alias cannot select ${modeName} mode: ${id}`);
        }
        if (entry.raw?.type === "VARIABLE_ALIAS") {
            const target = resolve(entry.raw.id, modeName, path.concat(id));
            if (target.type !== variable.type) {
                throw new Error(`Foundation alias type mismatch: ${id}`);
            }
            return { ...target, path: [id, ...target.path] };
        }
        return { value: entry.raw, type: variable.type, path: [id] };
    }

    for (const variable of variables) {
        for (const entry of variable.entries) {
            const expected = resolve(variable.id, entry.modeName);
            const resolved = entry.resolved;
            if (!resolved?.resolved || resolved.kind !== variable.type.toLowerCase()
                || resolved.sourceVariable !== expected.path.at(-1)
                || resolved.sourceName !== byID.get(expected.path.at(-1)).name
                || resolved.modeId !== entry.modeId || resolved.modeName !== entry.modeName
                || JSON.stringify(resolved.path) !== JSON.stringify(expected.path)) {
                throw new Error(`Stale Foundation alias provenance: ${variable.name}/${entry.modeName}`);
            }
            if (variable.type === "COLOR") {
                for (const channel of ["r", "g", "b", "a"]) {
                    const value = expected.value?.[channel] ?? (channel === "a" ? 1 : undefined);
                    const stored = resolved.color?.[channel];
                    if (!Number.isFinite(value) || value < 0 || value > 1
                        || !Number.isFinite(stored) || Math.fround(value) !== Math.fround(stored)) {
                        throw new Error(`Stale Foundation color: ${variable.name}/${entry.modeName}/${channel}`);
                    }
                }
            } else if (variable.type === "FLOAT") {
                if (!Number.isFinite(expected.value) || expected.value !== resolved.value) {
                    throw new Error(`Stale Foundation number: ${variable.name}/${entry.modeName}`);
                }
            } else if (!["STRING", "BOOLEAN"].includes(variable.type)
                || typeof expected.value !== (variable.type === "STRING" ? "string" : "boolean")
                || expected.value !== resolved.value) {
                throw new Error(`Invalid Foundation value: ${variable.name}/${entry.modeName}`);
            }
        }
    }
}

function loadSemanticVariables() {
    const source = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
    const foundation = source.source.currentFoundation;
    if (foundation) {
        validateFoundationGraph(source);
    }
    const semanticCollectionID = foundation?.semanticCollectionId ?? "870:12595";
    const expectedColorCount = foundation?.canonicalColorCount ?? 84;
    const variables = source.variables.filter(
        (variable) =>
            variable.set?.kind === "guid" &&
            variable.set.id === semanticCollectionID &&
            !variable.compatibilityOnly &&
            variable.type === "COLOR"
    );

    if (variables.length !== expectedColorCount) {
        throw new Error(
            `Expected ${expectedColorCount} semantic color variables, found ${variables.length}`
        );
    }

    const actual = source.actualComponentBindings;
    if (!actual?.source?.collectionId || !actual.roleVariableIDs) {
        throw new Error("DesignTokens.json is missing actual binding metadata");
    }

    const rowsByID = new Map(actual.rows.map((row) => [row.id, row]));
    const roleEntries = Object.entries(actual.roleVariableIDs);
    if (roleEntries.length !== actual.rows.length) {
        throw new Error(
            `Actual role map must cover every bound row: ${roleEntries.length}/${actual.rows.length}`
        );
    }
    const actualColorNames = new Set();

    for (const [name, id] of roleEntries) {
        const row = rowsByID.get(id);
        if (!row || row.name !== name) {
            throw new Error(`Actual binding ID does not match ${name}: ${id}`);
        }
        if (row.collection !== actual.source.collectionId) {
            throw new Error(`Actual binding is not from external Semantic: ${id}`);
        }
        if (row.type === "COLOR") {
            actualColorNames.add(name);
        }
    }

    if (actualColorNames.size !== 52) {
        throw new Error(
            `Expected 52 actual semantic colors, found ${actualColorNames.size}`
        );
    }

    const localColorNames = new Set(variables.map((variable) => variable.name));
    for (const name of actualColorNames) {
        if (!localColorNames.has(name)) {
            throw new Error(`Actual binding is not present in local roles: ${name}`);
        }
    }

    const semanticVariables = variables.map((variable) => {
        const actualID = actual.roleVariableIDs[variable.name];
        if (!actualID) {
            validateLocalColor(variable);
            return variable;
        }

        const row = rowsByID.get(actualID);
        if (row.type !== "COLOR") {
            throw new Error(`${actualID} is not a color binding`);
        }

        const entries = row.resolved.map((resolved) => ({
            modeName: resolved.mode,
            resolved: { color: resolved.value }
        }));
        for (const modeName of ["Experiment", "General"]) {
            if (!entries.some((entry) => entry.modeName === modeName)) {
                throw new Error(`${actualID} is missing ${modeName} color`);
            }
        }

        if (foundation) {
            validateLocalColor(variable);
            return variable;
        }

        return { ...variable, entries };
    });

    const compatibilityVariables = source.variables.filter(
        (variable) => variable.compatibilityOnly && variable.type === "COLOR"
    );
    if (foundation && compatibilityVariables.length !== foundation.legacyVariableCount) {
        throw new Error("Final Foundation is missing an explicit public compatibility role");
    }
    for (const variable of compatibilityVariables) {
        if (localColorNames.has(variable.name)) {
            throw new Error(`Compatibility role duplicates a canonical role: ${variable.name}`);
        }
        validateLocalColor(variable);
    }

    return semanticVariables.concat(
        compatibilityVariables,
        loadComponentSpecificVariables(actual)
    );
}

function loadComponentSpecificVariables(actual) {
    const bindings = actual.componentSpecificBindings;
    if (!Array.isArray(bindings) || bindings.length === 0) {
        throw new Error(
            "DesignTokens.json is missing component-specific binding metadata"
        );
    }

    const names = new Set();
    return bindings.map((binding) => {
        if (!binding.role || binding.type !== "COLOR") {
            throw new Error("Component-specific color binding is invalid");
        }
        if (names.has(binding.role)) {
            throw new Error(`Duplicate component-specific color role: ${binding.role}`);
        }
        names.add(binding.role);

        if (!binding.source?.variableId || !binding.source.collectionId) {
            throw new Error(`Component-specific binding is missing source: ${binding.role}`);
        }
        if (!Array.isArray(binding.entries) || !binding.themeModeMap) {
            throw new Error(`Component-specific binding is missing modes: ${binding.role}`);
        }
        if (!Array.isArray(binding.consumerIds) || binding.consumerIds.length === 0) {
            throw new Error(`Component-specific binding is missing consumers: ${binding.role}`);
        }

        const entries = Object.entries(binding.themeModeMap).map(
            ([themeMode, sourceMode]) => {
                const entry = binding.entries.find(
                    (candidate) => candidate.modeName === sourceMode
                );
                if (!entry?.resolved?.color) {
                    throw new Error(
                        `${binding.source.variableId} is missing ${sourceMode} color`
                    );
                }
                return {
                    modeName: themeMode,
                    resolved: { color: entry.resolved.color }
                };
            }
        );

        for (const modeName of ["Experiment", "General"]) {
            if (!entries.some((entry) => entry.modeName === modeName)) {
                throw new Error(`${binding.role} is missing ${modeName} color`);
            }
        }

        for (const consumerId of binding.consumerIds) {
            if (!binding.consumers?.some((consumer) => consumer.consumerId === consumerId)) {
                throw new Error(
                    `${binding.role} is missing resolved consumer ${consumerId}`
                );
            }
        }

        return {
            id: binding.source.variableId,
            name: binding.role,
            type: binding.type,
            entries
        };
    });
}

function validateLocalColor(variable) {
    for (const modeName of ["Experiment", "General"]) {
        const entry = variable.entries.find(
            (candidate) => candidate.modeName === modeName
        );
        if (!entry?.resolved?.color) {
            throw new Error(`${variable.id} is missing ${modeName} color`);
        }
    }
}

function generateColorTokensSwift() {
    const variables = loadSemanticVariables();
    const lines = [
        "//",
        "//  ColorTokens.swift",
        "//  labcord-package-swift",
        "//",
        "//  Figma 색상 토큰과 SwiftUI ShapeStyle 연결",
        "//",
        "",
        "import SwiftUI",
        "",
        "/// 화면에서 사용하는 의미 기반 및 컴포넌트 전용 색상 역할입니다.",
        "///",
        "/// rawValue는 Figma 원본 이름을 그대로 보존합니다.",
        "public enum ColorToken: String, CaseIterable, Sendable {",
        ...variables.flatMap((variable) => [
            ...(variable.compatibilityOnly
                ? ["    /// 이전 공개 API와 값을 보존하는 호환 역할입니다."]
                : []),
            `    case ${camelCase(variable.name)} = ${JSON.stringify(variable.name)}`
        ]),
        "}",
        "",
        "/// 현재 환경의 LabcordTheme에서 색상 역할을 해석하는 ShapeStyle입니다.",
        "///",
        "/// 사용 예: .foregroundStyle(.labcord(.labelPrimary))",
        "public struct LabcordColor: ShapeStyle, Sendable {",
        "    public typealias Resolved = Color",
        "",
        "    public let token: ColorToken",
        "",
        "    public init(_ token: ColorToken) {",
        "        self.token = token",
        "    }",
        "",
        "    public nonisolated func resolve(in environment: EnvironmentValues) -> Color {",
        "        environment.labcordTheme.resolvedColor(",
        "            token,",
        "            colorScheme: environment.colorScheme",
        "        )",
        "    }",
        "}",
        "",
        "public extension ShapeStyle where Self == LabcordColor {",
        "    static func labcord(_ token: ColorToken) -> LabcordColor {",
        "        LabcordColor(token)",
        "    }",
        "}",
        "",
        "private struct LabcordRGBA: Sendable {",
        "    let red: Float",
        "    let green: Float",
        "    let blue: Float",
        "    let opacity: Float",
        "",
        "    init(_ rgb: UInt32, _ opacity: Float) {",
        "        red = Float((rgb >> 16) & 0xFF) / 255",
        "        green = Float((rgb >> 8) & 0xFF) / 255",
        "        blue = Float(rgb & 0xFF) / 255",
        "        self.opacity = opacity",
        "    }",
        "",
        "    var color: Color {",
        "        Color(",
        "            red: Double(red),",
        "            green: Double(green),",
        "            blue: Double(blue),",
        "            opacity: Double(opacity)",
        "        )",
        "    }",
        "}",
        "",
        "private enum ColorTokenPalette {",
        "    // swiftlint:disable cyclomatic_complexity function_body_length",
        "    static func value(",
        "        for token: ColorToken,",
        "        context: ThemeContext",
        "    ) -> LabcordRGBA {",
        "        switch token {"
    ];

    for (const variable of variables) {
        const experiment = variable.entries.find(
            (entry) => entry.modeName === "Experiment"
        ).resolved.color;
        const general = variable.entries.find(
            (entry) => entry.modeName === "General"
        ).resolved.color;

        lines.push(
            `        case .${camelCase(variable.name)}:`,
            `            return color(${colorLiteral(experiment)}, ${colorLiteral(general)}, context)`
        );
    }

    lines.push(
        "        }",
        "    }",
        "",
        "    // swiftlint:enable cyclomatic_complexity function_body_length",
        "",
        "    private static func color(",
        "        _ experiment: LabcordRGBA,",
        "        _ general: LabcordRGBA,",
        "        _ context: ThemeContext",
        "    ) -> LabcordRGBA {",
        "        context == .experiment ? experiment : general",
        "    }",
        "}",
        "",
        "extension LabcordTheme {",
        "    /// 테마의 고정 appearance를 기준으로 색상을 반환합니다.",
        "    /// .system은 View 밖에서 사용할 때 context를 fallback으로 사용합니다.",
        "    public func color(_ token: ColorToken) -> Color {",
        "        resolvedColor(token, colorScheme: nil)",
        "    }",
        "",
        "    /// Environment의 colorScheme을 명시해 system appearance를 해석합니다.",
        "    public func color(",
        "        _ token: ColorToken,",
        "        colorScheme: ColorScheme",
        "    ) -> Color {",
        "        resolvedColor(token, colorScheme: colorScheme)",
        "    }",
        "",
        "    fileprivate func resolvedColor(",
        "        _ token: ColorToken,",
        "        colorScheme: ColorScheme?",
        "    ) -> Color {",
        "        let context = resolvedContext(for: colorScheme)",
        "        return ColorTokenPalette.value(for: token, context: context).color",
        "    }",
        "}"
    );

    return lines.join("\n") + "\n";
}

const generated = generateColorTokensSwift();
const shouldWrite = process.argv.includes("--write");
const shouldCheck = process.argv.includes("--check");

if (!shouldWrite && !shouldCheck) {
    console.error("Usage: generate-color-tokens.js --check|--write");
    process.exit(2);
}

if (shouldCheck) {
    const current = fs.readFileSync(outputPath, "utf8");
    if (current !== generated) {
        let index = 0;
        while (index < current.length && current[index] === generated[index]) {
            index += 1;
        }
        console.error(`ColorTokens.swift is out of date at byte ${index}`);
        console.error("Run generate-color-tokens.js --write to regenerate it.");
        process.exitCode = 1;
    } else {
        console.log("ColorTokens.swift matches DesignTokens.json");
    }
}

if (shouldWrite) {
    fs.writeFileSync(outputPath, generated);
    console.log(`Wrote ${path.relative(repositoryRoot, outputPath)}`);
}
