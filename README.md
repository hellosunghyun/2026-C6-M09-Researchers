# :iphone: Labcord

실험 기록을 돕는 iPhone · Apple Watch 앱을 개발하고 있습니다.
현재 `develop`에서는 Apple Watch 연결 정보 확인 화면과 실험 기록을 위한 공통 모델을
구현했습니다. 전체 실험 기록 흐름은 개발 중입니다.

로고·커버 이미지는 아직 준비되지 않았습니다. 저장소의 AppIcon은 빈 이미지여서
소개용 로고로 사용하지 않았습니다.

## :fireworks: Screenshots

공유 가능한 주요 화면 스크린샷은 아직 준비되지 않았습니다.
현재 iPhone 앱의 시작 화면은 [WatchPairingView](Researchers/Features/WatchPairing/WatchPairingView.swift)이며,
Apple Watch의 기기 이름, 사용 가능 상태, 배터리 정보를 표시합니다.

## :framed_picture: Demo (optional)

공개 데모 영상과 스토어 링크는 아직 준비되지 않았습니다.

## :pushpin: Features

현재 `develop` 코드에서 확인할 수 있는 구현 범위입니다.

- **Apple Watch 연결 정보 확인**: WatchConnectivity를 통해 연결 준비 상태를 관찰하고
  기기 이름과 배터리 정보를 요청해 iPhone 화면에 표시합니다.
  ([화면 로직](Researchers/Features/WatchPairing/WatchPairingFeature.swift),
  [iOS 통신 모듈](Packages/ResearchersModules/Sources/LabcordiOS/WatchConnectivity),
  [watchOS 통신 모듈](Packages/ResearchersModules/Sources/LabcordWatchOS/WatchConnectivity))
- **실험 기록 데이터 모델**: 실험 상태·상태 이력·일시정지, 사진·음성·영상·타이머 기록의
  메타데이터, 프로토콜의 시간·재료·시료·용어·단위를 표현하는 공통 모델을 구현했습니다.
  ([모델](Packages/ResearchersModules/Sources/LabcordShared/Models))
  기록 생성·촬영·전사·타이머 실행 UI가 완성됐다는 뜻은 아닙니다.

Apple Watch 선택 버튼의 다음 동작과 전체 실험 흐름은 아직 연결되지 않았고,
watchOS 시작 화면은 기본 화면입니다. 손목 제스처·음성 기록, 온디바이스 문서 파싱 등은
현재 `develop` 앱의 완성 기능으로 소개하지 않습니다.
[기술 검증 목록](docs/Technical%20Verification/README.md)의 검증 상태는 앱 통합 완료와 구분합니다.

## :sparkles: Skills & Tech Stack

| 영역 | 사용 기술 |
| --- | --- |
| 앱 UI | Swift, SwiftUI · iOS / watchOS |
| 상태 관리 | [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) |
| 기기 통신 | WatchConnectivity |
| 데이터 모델 | Foundation, SwiftData |
| Watch 기기 정보 | [DeviceKit](https://github.com/devicekit/DeviceKit) |
| 모듈 구성 | Swift Package Manager · LabcordShared, LabcordDesignSystem, LabcordiOS, LabcordWatchOS |
| 기존 CI | GitHub Actions · Build, SwiftLint, Main Branch Guard |

앱 타깃의 배포 대상은 iOS 27 / watchOS 27입니다. 로컬 패키지는
`swift-tools-version: 6.4`를 사용합니다. 설정은
[Xcode 프로젝트](Researchers.xcodeproj/project.pbxproj)와
[Package.swift](Packages/ResearchersModules/Package.swift)에서 확인할 수 있습니다.

## :people_hugging: Authors

데빈, 로렌스, 린, 블레어, 원, 테오가 함께 만듭니다.

- [@hellosunghyun](https://github.com/hellosunghyun)
- [@junghongseop](https://github.com/junghongseop)
- [@wondrone0113](https://github.com/wondrone0113)
- [@ryuhwagodong](https://github.com/ryuhwagodong)
- [@Seoyeon94](https://github.com/Seoyeon94)

기존 CODEOWNERS의 `by_zip`은 GitHub 프로필 조회에서 404가 반환되어 링크를 넣지
않았습니다. 해당 팀원의 현재 GitHub 계정은 확인 후 추가할 예정입니다.
