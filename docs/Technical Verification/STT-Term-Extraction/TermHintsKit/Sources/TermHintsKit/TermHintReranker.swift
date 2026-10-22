import Foundation

/// GB 랭커: sklearn GradientBoostingClassifier JSON export 추론 + tier 내 safe-P 재정렬
/// rr_gb.json: {init, lr, trees:[{f,th,l,r,v}], kinds:[16], safe_p}
public struct GBReranker {
  let initScore: Double
  let localLearningRate: Double
  let trees: [TreeArrays]
  let safeP: Int
  public static var substrDF: [String: Double] = [:]  // ko_substr_df.json (norm → df)

  static let kinds = [
    "pool", "delim", "word", "ngram", "ko_inner", "charngram", "ext", "path",
    "wsnap", "pooljoin", "piecejoin", "dotsplit", "duphalf", "kospjoin", "cleanvar", "oligo"
  ]
  static let kindIdx: [String: Int] = Dictionary(
    uniqueKeysWithValues: kinds.enumerated().map { ($0.1, $0.0) })
  static let particleSuffixes = [
    "에서", "으로", "까지", "부터", "처럼", "보다",
    "은", "는", "이", "가", "을", "를", "의", "에", "로", "도", "만", "와", "과", "며", "고"
  ]

  public init?(jsonPath: String) {
    guard let localData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
      let localNextIndex = try? JSONSerialization.jsonObject(with: localData) as? [String: Any],
      let localTree = localNextIndex["trees"] as? [[String: Any]]
    else { return nil }
    initScore = (localNextIndex["init"] as? NSNumber)?.doubleValue ?? 0
    localLearningRate = (localNextIndex["lr"] as? NSNumber)?.doubleValue ?? 0.1
    safeP = (localNextIndex["safe_p"] as? NSNumber)?.intValue ?? 25
    var localTrees: [TreeArrays] = []
    for localToken in localTree {
      guard let localField = localToken["f"] as? [Int],
        let localThresholds = localToken["th"] as? [Double],
        let localLeft = localToken["l"] as? [Int], let localResult = localToken["r"] as? [Int],
        let localValue = localToken["v"] as? [Double]
      else { return nil }
      localTrees.append(
        TreeArrays(
          fields: localField, thresholds: localThresholds, left: localLeft,
          right: localResult, values: localValue))
    }
    trees = localTrees
  }

  public func predict(_ localInput: [Double]) -> Double {
    var localString = initScore
    for localToken in trees {
      var localCount = 0
      while localToken.fields[localCount] >= 0 {
        localCount =
          localInput[localToken.fields[localCount]] <= localToken.thresholds[localCount]
          ? localToken.left[localCount] : localToken.right[localCount]
      }
      localString += localLearningRate * localToken.values[localCount]
    }
    return 1.0 / (1.0 + exp(-localString))
  }

  static func hasHangul(_ localString: String) -> Bool {
    localString.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
  }
  static func particleEnd(_ localString: String) -> Bool {
    let localToken = localString.trimmingCharacters(in: .whitespaces)
    return particleSuffixes.contains { localToken.hasSuffix($0) }
  }

  /// 피처 38개 — Python rr_cache.feats와 동일 순서
  static func feats(_ context: RankFeatureContext) -> [Double] {
    let localString = TermHintDecoder.sliceStr(context.chars, context.start, context.end)
    let localCount = HintNorm.norm(localString)
    let scal = localString.unicodeScalars
    let words = localString.split { $0.isWhitespace }
    let localHangul = hasHangul(localString)
    var localValue: [Double] = [
      Double(context.score), log1p(Double(context.score)), Double(context.tier),
      context.positionFraction, context.overallFraction,
      Double(scal.count), Double(words.count), Double(localCount.unicodeScalars.count),
      scal.contains { $0.properties.numericType != nil || ($0.value >= 48 && $0.value <= 57) }
        ? 1 : 0,
      scal.contains { $0.properties.isUppercase } ? 1 : 0,
      localHangul ? 1 : 0,
      localString.contains("-") ? 1 : 0,
      localString == localString.lowercased() ? 1 : 0,
      (scal.first.map { $0.properties.isUppercase } ?? false) ? 1 : 0,
      (context.knownTerms?.contains(localCount) ?? false) ? 1 : 0,
      localHangul ? log1p(substrDF[localCount] ?? 0) : 0,
      (localHangul && particleEnd(localString)) ? 1 : 0,
      context.topTerms.contains(localCount) ? 1 : 0,
      localCount.unicodeScalars.count <= 2 ? 1 : 0,
      context.tier == 1 ? 1 : 0, context.tier == 2 ? 1 : 0, context.tier == 3 ? 1 : 0
    ]
    var localOneHot = [Double](repeating: 0, count: kinds.count)
    if let localKindIndex = kindIdx[context.kind] { localOneHot[localKindIndex] = 1 }
    localValue.append(contentsOf: localOneHot)
    return localValue
  }

  /// merged (a,b,sc,t2,nf,kind,tier) — tier 내 상위 safeP 유지 + 나머지 재점수 정렬
  public func reorder(
    _ merged: [MergedCandidate], chars: [Unicode.Scalar], lang: String
  ) -> [MergedCandidate] {
    let total = merged.count
    // topn: 전체 후보 중 점수 상위 20개의 norm
    let top20 = merged.enumerated().sorted {
      $0.1.score > $1.1.score || ($0.1.score == $1.1.score && $0.0 < $1.0)
    }
    .prefix(20)
    var topn = Set<String>()
    for (_, localCandidate) in top20 {
      topn.insert(
        HintNorm.norm(TermHintDecoder.sliceStr(chars, localCandidate.start, localCandidate.end)))
    }
    // tier별 위치/개수 (baseline 순서 기준)
    var tcnt = [Int: Int]()
    for localCandidate in merged { tcnt[localCandidate.tier, default: 0] += 1 }
    var seen = [Int: Int]()
    var localPositions = [Double](repeating: 0, count: total)
    for (localNextIndex, localCandidate) in merged.enumerated() {
      seen[localCandidate.tier, default: 0] += 1
      let localPositionFraction =
        Double(seen[localCandidate.tier]!) / Double(tcnt[localCandidate.tier]!)
      localPositions[localNextIndex] = predict(
        GBReranker.feats(
          RankFeatureContext(
            chars: chars, start: localCandidate.start, end: localCandidate.end,
            score: localCandidate.score, kind: localCandidate.kind,
            tier: localCandidate.tier, positionFraction: localPositionFraction,
            overallFraction: Double(localNextIndex + 1) / Double(total),
            topTerms: topn, knownTerms: TermHintDecoder.knownTerms)))
    }
    var out: [MergedCandidate] = []
    out.reserveCapacity(total)
    for tier in [1, 2, 3] {
      let idx = merged.enumerated().compactMap { $0.1.tier == tier ? $0.0 : nil }
      let head = idx.prefix(safeP)
      let tail = idx.dropFirst(safeP).sorted {
        localPositions[$0] > localPositions[$1]
          || (localPositions[$0] == localPositions[$1] && $0 < $1)
      }
      for localIndex in head { out.append(merged[localIndex]) }
      for localIndex in tail { out.append(merged[localIndex]) }
    }
    return out
  }
}
