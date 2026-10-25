---
name: architecture
description: Labcord의 상태 관리나 기능 구조를 설계·검토할 때 Notion의 TCA 사용 예정과 현재 프로젝트의 TCA 적용 범위를 확인한다.
---

# 아키텍처 맥락 확인

출처: [Notion 개발 컨벤션의 Pattern/Architecture](https://sassy-cloth-fbe.notion.site/3fa06046c66e804eb90bcfb3d7341498), 2026-10-25 확인.

원문은 `TCA 사용할 예정`이라고 명시하고
[The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)를 연결한다.
현재 저장소는 `Packages/ResearchersModules/Package.swift`와
`Researchers/Features/WatchPairing/WatchPairingFeature.swift`에서 TCA 사용을 확인할 수 있다.

설계나 리뷰 시 이 계획과 해당 작업 주변의 실제 코드를 확인한다. 제안이 현재 적용된
상태 관리와 맞는지 설명한다. Notion에는 상세 계층, 폴더 구조, 의존성 방향 규칙이 없다.
모든 모델을 Reducer로 바꾸거나 새 아키텍처 규칙을 합의된 것으로 주장하지 않는다.

원문과 구현이 달라지면 차이를 알리고 확인 날짜를 갱신한다. 이 Skill 자체는 아키텍처
교체나 작업 범위 밖 코드 변경 권한을 부여하지 않는다.
