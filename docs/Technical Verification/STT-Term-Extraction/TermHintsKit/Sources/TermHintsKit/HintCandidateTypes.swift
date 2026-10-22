import Foundation

struct TaggedSpan {
  let start: Int
  let end: Int
  let kind: String
}

struct ScoredSpan {
  let start: Int
  let end: Int
  let score: Float
}

struct CandidateScoreComputer {
  let probs: [Float]
  let unitOffsets: [(Int, Int)]
  let orderedOffsets: Bool

  func score(_ localInput: Int, _ localOutput: Int, mode: String) -> Float {
    var vals: [Float] = []
    if orderedOffsets {
      var localLowerBound = 0
      var localUpperBound = unitOffsets.count
      while localLowerBound < localUpperBound {
        let mid = localLowerBound + (localUpperBound - localLowerBound) / 2
        if unitOffsets[mid].1 <= localInput {
          localLowerBound = mid + 1
        } else {
          localUpperBound = mid
        }
      }
      let first = localLowerBound
      localUpperBound = unitOffsets.count
      while localLowerBound < localUpperBound {
        let mid = localLowerBound + (localUpperBound - localLowerBound) / 2
        if unitOffsets[mid].0 < localOutput {
          localLowerBound = mid + 1
        } else {
          localUpperBound = mid
        }
      }
      for localIndex in first..<localLowerBound { vals.append(probs[localIndex]) }
    } else {
      for (localIndex, localOffset) in unitOffsets.enumerated()
      where localOffset.0 < localOutput && localOffset.1 > localInput {
        vals.append(probs[localIndex])
      }
    }
    if vals.isEmpty { return 0 }
    if mode == "topHalf" {
      vals.sort(by: >)
      let localLimit = max(1, (vals.count + 1) / 2)
      return vals[0..<localLimit].reduce(0, +) / Float(localLimit)
    }
    return vals.reduce(0, +) / Float(vals.count)
  }
}

struct ExtractionInput {
  let text: String
  let chars: [Unicode.Scalar]
  let logits: [[Float]]
  let probs: [Float]
  let unitOffsets: [(Int, Int)]
  let language: String
  let termLimit: Int
  let token: Float
  let scorer: CandidateScoreComputer
}

struct ExtensionCandidates {
  let start: Int
  let end: Int
  let previous: (Int, Int)?
  let next: (Int, Int)?
}

struct ViterbiBuffers {
  var dynamic: [Double]
  var back: [(id: Int, from: Int)]

  init(count: Int) {
    dynamic = [Double](repeating: -Double.infinity, count: count + 1)
    back = [(id: Int, from: Int)](repeating: (-1, -1), count: count + 1)
  }
}

struct NormalizedSource {
  let norm: [UInt8]
  let src: [ClosedRange<Int>]
}

struct ParsedPiece {
  let name: String
  let score: Double
  let type: Int
}

struct WindowUnitOutput {
  var tokenIndices: [Int] = []
  var rangeStart: [Double] = []
  var rangeEnd: [Double] = []
  var mapped: [Int] = []
}

struct GeneratedRegion {
  let start: Int
  let end: Int
  let emitRoot: Bool
}

struct TaggedWorkItem {
  let start: Int
  let end: Int
  let depth: Int
}

struct TagGenerationInput {
  let text: [Unicode.Scalar]
  let start: Int
  let end: Int
  let language: String
  let maxN: Int
  let depth: Int
  let emitRoot: Bool
  let scorer: ((Int, Int) -> Float)?
}

struct TaggedSpanBuffer {
  var spans: [TaggedSpan] = []
  var seen: Set<Int> = []
}

struct WordNgramInput {
  let text: [Unicode.Scalar]
  let start: Int
  let end: Int
  let maxN: Int
}

struct LedgerAnchorState {
  let projected: [(Int, Int)?]
  let reasons: [[String]]
  let unitToken: [Int]
  let anchor: [Int]
  let anchored: [Int: [Int]]
}

struct CleanPiece {
  let start: Int
  let end: Int
  let weak: Bool
}

struct CandidateRecord {
  let start: Int
  let end: Int
  let score: Float
  let tierTwo: Bool
  let noFilter: Bool
  let kind: String
}

public struct MergedCandidate {
  public let start: Int
  public let end: Int
  public let score: Float
  public let tierTwo: Bool
  public let noFilter: Bool
  public let kind: String
  public let tier: Int

  public init(
    start: Int, end: Int, score: Float, tierTwo: Bool, noFilter: Bool, kind: String, tier: Int
  ) {
    self.start = start
    self.end = end
    self.score = score
    self.tierTwo = tierTwo
    self.noFilter = noFilter
    self.kind = kind
    self.tier = tier
  }
}

struct TreeArrays {
  let fields: [Int]
  let thresholds: [Double]
  let left: [Int]
  let right: [Int]
  let values: [Double]
}

struct RankFeatureContext {
  let chars: [Unicode.Scalar]
  let start: Int
  let end: Int
  let score: Float
  let kind: String
  let tier: Int
  let positionFraction: Double
  let overallFraction: Double
  let topTerms: Set<String>
  let knownTerms: Set<String>?
}

struct SafeToken {
  let start: Int
  let end: Int
  let index: Int
}

public struct SafeUnitResult {
  public let offsets: [(Int, Int)]
  public let unsafe: [Bool]
  public let cp16: [Int]

  public init(offsets: [(Int, Int)], unsafe: [Bool], cp16: [Int]) {
    self.offsets = offsets
    self.unsafe = unsafe
    self.cp16 = cp16
  }
}

public struct LedgerBuildResult {
  public let windows: [TermPreprocessor.LedgerWindow]
  public let unitToSafeToken: [Int]
  public let anchors: [Int]
  public let projected: [(Int, Int)?]
  public let reasons: [[String]]

  public init(
    windows: [TermPreprocessor.LedgerWindow], unitToSafeToken: [Int], anchors: [Int],
    projected: [(Int, Int)?], reasons: [[String]]
  ) {
    self.windows = windows
    self.unitToSafeToken = unitToSafeToken
    self.anchors = anchors
    self.projected = projected
    self.reasons = reasons
  }
}
