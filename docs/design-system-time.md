# 타이머 시간 표시

Foundation `Duration`을 표시하는 `FormatStyle`을 제공한다.
시간의 저장·실행·유효 범위 검증은 호출부가 담당한다.

```swift
Text(Duration.seconds(8_160), format: .labcordDuration) // 2시간 16분
Text(Duration.seconds(309), format: .labcordDuration) // 5분 9초

Text(Duration.seconds(5), format: .labcordClock()) // 00:05
Text(Duration.seconds(5), format: .labcordClock(includesHours: true)) // 00:00:05
```

설정 시간은 값이 있는 시·분·초를 한국어 단위와 함께 표시한다.
값이 0인 중간 단위와 숫자 앞의 0은 생략하며 전체가 0이면 `0초`다.
초 미만은 표시하지 않는다. 음수·24시간 이상을 전달해도 값을 조용히 보정하지 않는다.

남은 시간의 시계 자릿수는 호출부가 선택한다. 시간이 줄어도 `includesHours: true`이면
`00:00:00` 형식을 유지한다. 숫자 폭과 숫자 전환 애니메이션은 표시 View에서 설정한다.

값과 마지막 단위를 서로 다른 글자 스타일로 표시할 수 있다.

```swift
let display = TimerDurationFormatStyle().components(.seconds(309))
// display.value == "5분 9", display.unit == "초"
```

`TimerFormattingTests`는 한국어 복합 단위·값/단위 분리·고정 자릿수·초 미만과
범위 밖 값의 표시를 검사한다. 화면 레이아웃이나 실제 타이머 실행을 검사하지 않는다.

Xcode에서 `Packages/ResearchersModules`를 열고 `DesignSystem` 스킴과
iOS 시뮬레이터를 선택해 테스트한다. 이 스킴은 `LabcordDesignSystemTests`를 실행한다.
