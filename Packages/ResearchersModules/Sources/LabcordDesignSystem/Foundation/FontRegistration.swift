//
//  FontRegistration.swift
//  labcord-package-swift
//
//  Created by 정홍섭 on 10/23/26.
//

import CoreText
import Foundation

@MainActor
public enum FontRegistration {
    private static var isRegistered = false

    @discardableResult
    public static func register() -> Bool {
#if os(watchOS)
        // watchOS는 플랫폼 SF Pro를 사용하므로 패키지 리소스를 조회하거나
        // 프로세스 수준의 폰트 등록을 수행하지 않습니다.
        return true
#else
        if isRegistered { return true }

        guard let url = Bundle.module.url(
            forResource: "PretendardVariable",
            withExtension: "ttf"
        ) else {
            return false
        }

        var registrationError: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(
            url as CFURL,
            .process,
            &registrationError
        )

        if didRegister {
            isRegistered = true
            return true
        }

        guard let registrationError else { return false }
        let error = registrationError.takeUnretainedValue()
        let isAlreadyRegistered = CFEqual(
            CFErrorGetDomain(error),
            kCTFontManagerErrorDomain
        ) && CFErrorGetCode(error) == CTFontManagerError.alreadyRegistered.rawValue

        isRegistered = isAlreadyRegistered
        return isAlreadyRegistered
#endif
    }
}
