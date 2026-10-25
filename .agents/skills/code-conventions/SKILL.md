---
name: code-conventions
description: Labcord Swift 코드를 작성·정리하거나 코드 스타일과 lint 결과를 검토할 때 사용한다.
---

# Swift 코드 스타일

## 작성 규칙

- 들여쓰기는 스페이스 2칸, 콜론 공백은 뒤쪽만 사용한다. 연산자 함수 선언은 연산자와 괄호를 한 칸 띄운다.
- 긴 선언·호출은 매개변수별로 나누고 클로저 인자가 여러 개면 줄을 나눈다. 긴 조건 바인딩은 정렬하며 guard의 else는 guard와 맞춘다.
- 줄은 99자 이내로 작성한다. 빈 줄의 공백을 없애고 파일 끝 개행과 MARK 앞뒤 빈 줄을 둔다.
- import는 내장·외부 모듈을 빈 줄로 나누고 알파벳순으로 정렬한다.
- 타입·프로토콜은 UpperCamelCase, 함수·변수·상수·enum case는 lowerCamelCase를 사용한다. 클래스 접두사와 불필요한 get을 피한다.
- 약어는 이름 첫머리에서 소문자, 이후에는 대문자로 쓴다. Action 함수는 주어·동사·목적어로 명명하고 Tap/Press, will/did, should의 의미를 구분한다. Delegate 메서드에는 프로토콜 이름의 문맥을 담는다.
- 무인자·무반환 클로저는 `() -> Void`로 표현한다. 매개변수 괄호와 추론 가능한 타입은 생략하고 마지막 단일 클로저는 후행 클로저로 작성한다.
- 멤버 접근은 self를 명시하고 구조체 생성자를 사용한다. 컬렉션 타입은 [T], [K: V]로 쓴다.
- 문서 주석은 ///, 코드 구분은 // MARK:를 사용한다.
- 선언 시 초기화를 권장하고 관련 상수는 enum으로 묶는다. 상속하지 않는 클래스에는 final을 붙이고 프로토콜 구현은 extension으로 모은다.

## Lint 검증

- opt-in: empty_count, first_where, sorted_imports, trailing_closure, closure_spacing.
- line_length는 warning 99, error 150이다. trailing_whitespace, trailing_newline, colon, comma는 error다.
- CI는 `swiftlint --strict`로 확인한다. 스타일 안내의 99자 작성 기준과 lint의 150자 error 기준을 혼동하지 않는다.
- 변경한 Swift 코드의 lint 결과와 미검증 범위를 보고한다. 문서 정리를 이유로 formatter·의존성·앱 테스트를 추가하거나 기존 코드를 일괄 수정하지 않는다.
