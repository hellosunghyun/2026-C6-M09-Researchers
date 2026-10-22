import Foundation
import PDFKit

/// 페이지를 순서대로 읽는 기본 PDF 파서. 표·삽입 그림 처리는 다음 PR에서 연결한다.
nonisolated enum DocumentPDFParser {
  static func parse(
    _ data: Data, options: DocumentParserOptions, progress: DocumentParser.ProgressHandler?
  ) async throws -> DocumentParseResult {
    guard let document = PDFDocument(data: data) else {
      throw DocumentParsingError.malformedDocument
    }
    guard !document.isLocked else { throw DocumentParsingError.encryptedDocument }
    guard document.pageCount > 0 else { throw DocumentParsingError.malformedDocument }
    var blocks: [DocumentBlock] = []
    var warnings: [DocumentWarning] = []
    let count = min(document.pageCount, max(1, options.maximumDocumentPages))
    for index in 0..<count {
      try Task.checkCancellation()
      do {
        let pageBlocks = try autoreleasepool {
          try extractPage(document.page(at: index), index: index,
                          options: options, warnings: &warnings)
        }
        blocks.append(contentsOf: pageBlocks)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        warnings.append(.init(code: .extractionFailed,
          message: "PDF page could not be extracted.", location: .init(page: index + 1)))
      }
      progress?(.init(inputIndex: 0, phase: .recognizingText,
        fractionCompleted: Double(index + 1) / Double(count)))
    }
    if count < document.pageCount {
      warnings.append(.init(code: .resourceLimitReached,
        message: "Remaining PDF pages exceeded the configured limit.",
        location: .init(page: count + 1)))
    }
    for index in blocks.indices { blocks[index].readingOrder = index }
    return DocumentParseResult(format: .pdf, blocks: blocks, warnings: warnings)
  }

  /// 본문을 먼저 보존하고 OCR 실패는 해당 페이지의 경고로 남긴다.
  private static func extractPage(
    _ page: PDFPage?, index: Int, options: DocumentParserOptions,
    warnings: inout [DocumentWarning]
  ) throws -> [DocumentBlock] {
    guard let page, let reference = page.pageRef else {
      throw DocumentParsingError.malformedDocument
    }
    let space = DocumentPDFPageSpace(page: reference)
    var native = nativeLines(page, index: index, space: space)
    guard let raster = space.render(page, maximumPixels: options.maximumImagePixels) else {
      warnings.append(.init(code: .resourceLimitReached,
        message: "PDF page exceeded the rasterization limit.", location: .init(page: index + 1)))
      return native
    }
    do {
      let recognized = try DocumentOCR.recognize(image: raster, orientation: .up,
        location: .init(page: index + 1))
      native.append(contentsOf: recognized.filter { !duplicate($0, in: native) })
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      warnings.append(.init(code: .imageOCRFailed,
        message: "PDF page OCR could not be completed.", location: .init(page: index + 1)))
    }
    return native
  }

  private static func nativeLines(
    _ page: PDFPage, index: Int, space: DocumentPDFPageSpace
  ) -> [DocumentBlock] {
    page.selection(for: space.page.getBoxRect(.mediaBox))?
      .selectionsByLine().compactMap { line in
        let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return DocumentBlock(kind: .paragraph, text: text, readingOrder: 0,
          location: .init(page: index + 1, bounds: space.normalized(line.bounds(for: page))))
      } ?? []
  }

  /// 공간적으로 겹치는 본문과 같은 문자열만 중복 OCR로 제외한다.
  private static func duplicate(_ candidate: DocumentBlock, in blocks: [DocumentBlock]) -> Bool {
    guard let bounds = candidate.location.bounds else { return false }
    let related = blocks.filter {
      guard !$0.text.isEmpty, let other = $0.location.bounds else { return false }
      return other.insetBy(dx: -0.005, dy: -0.005).intersects(bounds)
    }
    let value = normalized(candidate.text)
    return value.isEmpty || related.contains { normalized($0.text) == value }
      || normalized(related.map(\.text).joined()).contains(value)
  }

  private static func normalized(_ text: String) -> String {
    text.lowercased().filter { !$0.isWhitespace }
  }
}
