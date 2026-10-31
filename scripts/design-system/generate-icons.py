#!/usr/bin/env python3
"""Generate Labcord icon assets and the Swift icon contract from source SVGs.

The SVGs under ``icon-source`` are the only editable icon geometry.  The
generator wraps each path twice: once as a custom SF Symbol and once as a
template image asset whose 24x24 canvas is preserved for source-faithful
controls.  No Apple or third-party font glyph is embedded.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import xml.etree.ElementTree as ElementTree
from dataclasses import dataclass
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE_DIR = REPOSITORY_ROOT / "scripts/design-system/icon-source"
DEFAULT_ASSET_DIR = (
    REPOSITORY_ROOT
    / "Packages/ResearchersModules/Sources/LabcordDesignSystem/Recources/Icons.xcassets"
)
DEFAULT_SWIFT_OUTPUT = (
    REPOSITORY_ROOT
    / "Packages/ResearchersModules/Sources/LabcordDesignSystem/Components/LabcordIcon.swift"
)

# These values are the SF Symbols guide coordinates used by the isolated
# runtime proof.  The source path stays in its original 24x24 coordinate
# system; only the generated symbol wrapper is transformed.
CENTER_X = 1449.845
BASELINE = {"S": 696.0, "M": 1126.0, "L": 1556.0}
CAPLINE = {"S": 625.541, "M": 1055.54, "L": 1485.54}
SCALE = {"S": 0.783, "M": 1.0, "L": 1.29}
BASE_CAP_HEIGHT = 70.46
BASE_MARGIN_WIDTH = 110.89
MATRIX_PATTERN = re.compile(r"matrix\(([^)]*)\)")


@dataclass(frozen=True)
class SourceIcon:
    slug: str
    case_name: str
    path_data: str
    fill_rule: str
    source_text: str


def swift_case_name(slug: str) -> str:
    parts = [part for part in slug.split("-") if part]
    if not parts or any(not re.fullmatch(r"[A-Za-z0-9]+", part) for part in parts):
        raise ValueError(f"invalid icon source name: {slug}")
    return parts[0] + "".join(part[:1].upper() + part[1:] for part in parts[1:])


def parse_source(path: Path) -> SourceIcon:
    root = ElementTree.fromstring(path.read_text(encoding="utf-8"))
    view_box = root.attrib.get("viewBox")
    if view_box != "0 0 24 24":
        raise ValueError(f"{path.name}: expected a 24x24 viewBox, found {view_box!r}")

    paths = [
        element
        for element in root.iter()
        if element.tag.rsplit("}", 1)[-1] == "path"
    ]
    if len(paths) != 1:
        raise ValueError(f"{path.name}: expected one source path, found {len(paths)}")

    source_path = paths[0]
    path_data = source_path.attrib.get("d")
    if not path_data:
        raise ValueError(f"{path.name}: source path has no d attribute")

    return SourceIcon(
        slug=path.stem,
        case_name=swift_case_name(path.stem),
        path_data=path_data,
        fill_rule=source_path.attrib.get("fill-rule", "nonzero"),
        source_text=path.read_text(encoding="utf-8"),
    )


def load_sources(source_dir: Path) -> list[SourceIcon]:
    paths = sorted(source_dir.glob("*.svg"))
    if not paths:
        raise ValueError(f"no SVG sources found in {source_dir}")

    icons = [parse_source(path) for path in paths]
    slugs = [icon.slug for icon in icons]
    cases = [icon.case_name for icon in icons]
    if len(slugs) != len(set(slugs)):
        raise ValueError("duplicate icon source names")
    if len(cases) != len(set(cases)):
        raise ValueError("duplicate generated Swift case names")
    return icons


def escaped(value: str) -> str:
    return html.escape(value, quote=True)


def symbol_svg(icon: SourceIcon) -> str:
    source_d = escaped(icon.path_data)
    symbols: list[str] = []
    guides: list[str] = []

    for scale_name in ("S", "M", "L"):
        factor = BASE_CAP_HEIGHT / 24.0 * SCALE[scale_name]
        x_offset = CENTER_X - 1394.4 - 12.0 * factor
        y_offset = -24.0 * factor
        margin_half = BASE_MARGIN_WIDTH * SCALE[scale_name] / 2.0
        left_margin = CENTER_X - margin_half
        right_margin = CENTER_X + margin_half
        baseline = BASELINE[scale_name]
        capline = CAPLINE[scale_name]

        symbols.append(
            f'''  <g id="Regular-{scale_name}" transform="matrix(1 0 0 1 1394.4 {baseline:g})">
    <path class="monochrome-1" fill-rule="{escaped(icon.fill_rule)}" transform="matrix({factor:.9f} 0 0 {factor:.9f} {x_offset:.9f} {y_offset:.9f})" d="{source_d}"/>
  </g>'''
        )
        guides.extend(
            [
                f'  <line id="Baseline-{scale_name}" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="{baseline:g}" y2="{baseline:g}"/>',
                f'  <line id="Capline-{scale_name}" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="{capline:g}" y2="{capline:g}"/>',
                f'  <line id="left-margin-Regular-{scale_name}" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="{left_margin:.3f}" x2="{left_margin:.3f}" y1="{capline:g}" y2="{baseline:g}"/>',
                f'  <line id="right-margin-Regular-{scale_name}" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="{right_margin:.3f}" x2="{right_margin:.3f}" y1="{capline:g}" y2="{baseline:g}"/>',
            ]
        )

    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<!-- Generated from the exact Figma 24x24 source path. Do not edit this file. -->
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="3300" height="2200">
 <style>.monochrome-1 {{fill:#000000}}</style>
 <g id="Notes">
  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13" x="263" y="1933">Template v.4.0</text>
  <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13" x="263" y="1953">Labcord Phosphor {escaped(icon.slug)}</text>
 </g>
 <g id="Guides">
{chr(10).join(guides)}
 </g>
 <g id="Symbols">
{chr(10).join(symbols)}
 </g>
</svg>
'''
    validate_matrix_transforms(svg, icon.slug)
    return svg


def validate_matrix_transforms(svg: str, source_name: str) -> None:
    """Reject malformed SVG matrix transforms before writing generated assets.

    XML parsing alone accepts an attribute whose value ends after ``matrix(``;
    validate the transform grammar explicitly so generated SF Symbol assets
    cannot silently contain an unbalanced matrix expression.
    """
    transforms = re.findall(r'transform="([^"]+)"', svg)
    matrix_transforms = [value for value in transforms if value.startswith("matrix(")]
    if not matrix_transforms:
        raise ValueError(f"{source_name}: generated SVG has no matrix transforms")

    for transform in matrix_transforms:
        match = MATRIX_PATTERN.fullmatch(transform)
        if match is None:
            raise ValueError(f"{source_name}: malformed matrix transform {transform!r}")
        values = match.group(1).split()
        if len(values) != 6:
            raise ValueError(
                f"{source_name}: matrix transform must have 6 values: {transform!r}"
            )
        try:
            [float(value) for value in values]
        except ValueError as error:
            raise ValueError(
                f"{source_name}: matrix transform has non-numeric values: {transform!r}"
            ) from error


def artwork_svg(icon: SourceIcon) -> str:
    # Keep the original SVG canvas and path data.  The fill is made explicit
    # only for Xcode's template image rendering; it does not alter geometry.
    source = icon.source_text.replace('fill="currentColor"', 'fill="#000000"')
    return "<!-- Generated from the exact source SVG. Do not edit this file. -->\n" + source


def contents_json(filename: str, *, template: bool = False) -> str:
    properties: dict[str, object] = {"preserves-vector-representation": True}
    if template:
        properties["template-rendering-intent"] = "template"

    payload: dict[str, object] = {
        "images": [{"filename": filename, "idiom": "universal", "scale": "1x"}],
        "info": {"author": "labcord", "version": 1},
        "properties": properties,
    }
    return json.dumps(payload, indent=2) + "\n"


def symbol_contents_json(filename: str) -> str:
    payload = {
        "info": {"author": "labcord", "version": 1},
        "symbols": [{"filename": filename, "idiom": "universal"}],
    }
    return json.dumps(payload, indent=2) + "\n"


def swift_source(icons: list[SourceIcon]) -> str:
    cases = "\n".join(f"    case {icon.case_name} = \"{icon.slug}\"" for icon in icons)
    return f'''//
//  LabcordIcon.swift
//  labcord-package-swift
//
//  This file is generated by scripts/design-system/generate-icons.py.
//  Edit the source SVGs and regenerate instead of changing this mapping by hand.
//

import SwiftUI

// swiftlint:disable identifier_name
/// Figma node 697:9676에서 추출한 Labcord 기능 아이콘입니다.
///
/// `rawValue`는 생성 자산과 연결되는 안정적인 kebab-case 이름입니다.
public enum LabcordIcon: String, CaseIterable, Identifiable, Sendable {{
{cases}

    public var id: String {{
        rawValue
    }}

    fileprivate var symbolAssetName: String {{
        "labcord-symbol-\\(rawValue)"
    }}

    fileprivate var artworkAssetName: String {{
        "labcord-artwork-\\(rawValue)"
    }}
}}
// swiftlint:enable identifier_name

/// SF Symbols 자산으로 연결되는 아이콘입니다.
///
/// SwiftUI의 `.font`, `.imageScale`, `.symbolRenderingMode`, Dynamic Type을
/// 그대로 사용할 수 있습니다. Figma 24x24 캔버스를 고정해야 하는 내부 컨트롤은
/// `LabcordIconArtwork`를 사용합니다.
public extension Image {{
    init(labcordIcon icon: LabcordIcon) {{
        self.init(icon.symbolAssetName, bundle: .module)
    }}
}}

/// 원본 24x24 SVG 캔버스를 보존하는 내부 artwork 표현입니다.
///
/// SF Symbol의 cap-height 보정과 분리해, source frame이 필요한 컨트롤에서만
/// 사용합니다. `size`는 `relativeTo` 텍스트 스타일에 따라 Dynamic Type으로
/// scaling됩니다.
struct LabcordIconArtwork: View {{
    private let icon: LabcordIcon
    @ScaledMetric private var scaledSize: CGFloat

    init(
        icon: LabcordIcon,
        size: CGFloat,
        relativeTo: Font.TextStyle = .body
    ) {{
        self.icon = icon
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
    }}

    var body: some View {{
        Image(icon.artworkAssetName, bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: scaledSize, height: scaledSize)
            .accessibilityHidden(true)
    }}
}}
'''


def generated_files(
    icons: list[SourceIcon], asset_dir: Path, swift_output: Path
) -> dict[Path, str]:
    files: dict[Path, str] = {
        asset_dir / "Contents.json": '{\n  "info" : { "author" : "labcord", "version" : 1 }\n}\n',
        swift_output: swift_source(icons),
    }
    for icon in icons:
        symbol_name = f"labcord-symbol-{icon.slug}"
        symbol_dir = asset_dir / f"{symbol_name}.symbolset"
        files[symbol_dir / f"{symbol_name}.svg"] = symbol_svg(icon)
        files[symbol_dir / "Contents.json"] = symbol_contents_json(
            f"{symbol_name}.svg"
        )

        artwork_name = f"labcord-artwork-{icon.slug}"
        artwork_dir = asset_dir / f"{artwork_name}.imageset"
        files[artwork_dir / f"{artwork_name}.svg"] = artwork_svg(icon)
        files[artwork_dir / "Contents.json"] = contents_json(
            f"{artwork_name}.svg", template=True
        )
    return files


def stale_asset_dirs(asset_dir: Path, icons: list[SourceIcon]) -> list[Path]:
    expected = {
        f"labcord-symbol-{icon.slug}.symbolset" for icon in icons
    } | {f"labcord-artwork-{icon.slug}.imageset" for icon in icons}
    return sorted(
        path
        for path in asset_dir.iterdir()
        if path.is_dir() and path.name.endswith((".symbolset", ".imageset"))
        and path.name not in expected
    ) if asset_dir.exists() else []


def write_or_check(
    files: dict[Path, str], asset_dir: Path, icons: list[SourceIcon], check: bool
) -> int:
    mismatches: list[str] = []
    for path, expected in files.items():
        actual = path.read_text(encoding="utf-8") if path.exists() else None
        if actual != expected:
            mismatches.append(str(path.relative_to(REPOSITORY_ROOT)))
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(expected, encoding="utf-8")

    stale = stale_asset_dirs(asset_dir, icons)
    if stale:
        mismatches.extend(f"stale asset directory: {path.name}" for path in stale)

    if check:
        if mismatches:
            print("icon assets are out of date:")
            print("\n".join(f"- {item}" for item in mismatches))
            return 1
        print(f"icon assets are up to date ({len(icons)} icons)")
        return 0

    if mismatches:
        print(f"generated icon assets ({len(icons)} icons)")
    else:
        print("icon assets already match generated output")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail when generated files differ")
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--asset-dir", type=Path, default=DEFAULT_ASSET_DIR)
    parser.add_argument("--swift-output", type=Path, default=DEFAULT_SWIFT_OUTPUT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        icons = load_sources(args.source_dir)
        files = generated_files(icons, args.asset_dir, args.swift_output)
        return write_or_check(files, args.asset_dir, icons, args.check)
    except (OSError, ValueError, ElementTree.ParseError) as error:
        print(f"generate-icons: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
