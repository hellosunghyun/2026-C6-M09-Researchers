---
name: architecture
description: Labcord 상태 관리, Feature 구성, 데이터 저장·전송 또는 패키지 경계를 설계·검토할 때 사용한다.
---

# 앱과 패키지 구조

Swift, TCA, SwiftData를 사용한다. TCA의 State는 화면·로직에 필요한 데이터, Action은 사용자 동작과 외부 이벤트, Reducer는 상태 변경과 Effect, Store는 Action 전달과 상태·Effect 실행을 담당한다.

## Feature와 앱 경계

- 앱 시작점은 각 앱의 App에 두고 화면·사용자 흐름별로 Features를 나눈다.
- View는 상태를 표시하고 Action을 보낸다. 상태 변경과 동작 처리는 Feature가 맡는다.
- Feature 내부 구현과 전용 Components는 해당 Feature에서만 사용한다. 다른 Feature의 내부 구현을 직접 참조하지 않고 부모가 자식 Feature를 조합한다.
- 폴더 자체는 Swift 접근 제한이 아니므로 파일 내부 구현은 가능한 곳에 private을 적용한다.

## 저장과 전송

- 기기별 저장·통신 코드는 해당 앱에 둔다. iPhone이 영구 저장을 담당하고 SwiftData 코드는 iPhone의 Database/SwiftData에 둔다. Watch에는 SwiftData를 두지 않는다.
- Watch 입력은 WatchConnectivity로 iPhone에 보낸다. 공통 전송 형식은 Shared/Messages에 두고 변경 시 송신·수신 양쪽을 확인한다.
- 전송 요청·전송 완료·iPhone 저장 완료를 구분한다. iPhone 저장 확인 전 Watch에 저장 완료를 표시하지 않는다. 재전송 중복을 막도록 요청별 식별자를 사용한다.

## 공통 코드와 UI

- 코드는 처음 사용하는 앱에 작성하고 두 앱에서 필요해지면 Shared로 옮긴다. Shared에는 공통 모델·전송 형식·함수와 실제 공유하는 의존성을 둔다.
- Utils·Clients를 용도가 불명확한 코드의 보관함으로 사용하지 않는다.
- 공통 색상·간격은 DesignTokens, 플랫폼별 공통 UI는 각 DesignSystem 타깃에 둔다. 앱 전용 리소스는 각 앱 Resources에 둔다.
- Shared와 DesignSystem을 별도 로컬 패키지로 운영한다면 각각 Package.swift가 필요하다. 새 타깃은 사용하는 앱의 의존성 연결까지 확인한다.

데이터 폴더 표기에 Data와 Database가 함께 사용되며 현재 구현은 ResearchersModules의 여러 타깃으로 묶여 있다. 명명이나 패키지 분리 방식을 임의로 확정하거나 기존 구조를 일괄 이동하지 말고, 변경 대상의 실제 코드·타깃 연결과 차이를 확인한다.
