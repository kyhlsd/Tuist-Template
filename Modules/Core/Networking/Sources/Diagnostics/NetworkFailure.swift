//
//  NetworkFailure.swift
//  Networking
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// 생성 클라이언트가 던진 에러를 진단용 요약으로 줄인 값.
///
/// 에러 설명에는 쿼리가 붙은 URL 이나 요청 헤더가 들어갈 수 있으므로 타입과 코드만 남긴다.
/// 판정(`isReportable`)과 요약(`summary`)을 한 곳에 두어 로그와 보고가 같은 규칙을 따르게 한다.
public struct NetworkFailure: Sendable, Equatable {
    /// 실패한 operation. `ClientError` 가 아니면 `nil`.
    public let operationID: String?
    /// 원래 에러의 종류. 보고를 묶는 키다. 예: `URLError`, `DecodingError.dataCorrupted`.
    ///
    /// 연관값이 있는 enum 이면 case 이름을 붙인다. 같은 타입이라도 원인이 다른 에러를 따로 묶기 위해서다.
    /// 연관값에는 URL 이 들어갈 수 있으므로 case 이름만 쓴다. 연관값이 없는 case 는 타입 이름만 남는다.
    public let errorType: String
    /// `URLError` 의 코드. 그 밖의 에러는 `nil`.
    public let errorCode: Int?
    /// 로그용 한 단어. 예: `URLError(-1004)`, `DecodingError`. case 이름은 붙이지 않는다.
    public let summary: String
    /// 응답 헤더의 request ID. 응답이 없으면(전송 실패) `nil`.
    public let requestID: String?
    /// 클라이언트가 보고할 에러인지. 서버가 볼 수 있거나 사용자 환경 탓인 에러는 `false`.
    public let isReportable: Bool
    /// 취소(`CancellationError`, `URLError.cancelled`)인지. 실패가 아니므로 로그와 breadcrumb 레벨을 낮춘다.
    public let isCancellation: Bool

    /// 에러를 요약한다.
    ///
    /// 호출부가 받는 에러는 늘 `ClientError` 이므로 원래 에러와 operation ID 를 꺼낸다.
    public static func describe(_ error: any Error) -> NetworkFailure {
        let clientError = error as? ClientError
        let underlying = clientError?.underlyingError ?? error
        let urlError = underlying as? URLError
        // `any Error` 에 담긴 URLError 는 런타임 타입이 NSError 로 보이므로 이름을 직접 정한다.
        let typeName = urlError == nil ? String(describing: type(of: underlying)) : TypeName.urlError
        let errorType = caseName(of: underlying).map { "\(typeName).\($0)" } ?? typeName

        return NetworkFailure(
            operationID: clientError?.operationID,
            errorType: errorType,
            errorCode: urlError?.code.rawValue,
            summary: urlError.map { "\(TypeName.urlError)(\($0.code.rawValue))" } ?? typeName,
            // 응답은 디코딩 실패일 때만 있다. RequestIDMiddleware 가 넣은 값이다.
            requestID: clientError?.response?.headerFields[NetworkDefaults.requestIDField],
            isReportable: isReportable(underlying),
            isCancellation: isCancellation(underlying)
        )
    }

    /// 연관값이 있는 enum case 의 이름. 그 밖에는 `nil`.
    ///
    /// `String(describing:)` 은 `CustomStringConvertible` 설명문(URL 이 들어갈 수 있음)을 돌려줄 수 있어 쓰지 않는다.
    /// `Mirror` 의 첫 자식 라벨은 case 이름이고 값은 담지 않는다.
    private static func caseName(of error: any Error) -> String? {
        let mirror = Mirror(reflecting: error)
        guard mirror.displayStyle == .enum else {
            return nil
        }
        return mirror.children.first?.label
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    /// 취소, 오프라인류, 인증 만료는 보고하지 않는다.
    ///
    /// 취소는 실패가 아니고, 오프라인은 사용자 환경 탓이며, 인증 만료는 서버가 기록한다.
    private static func isReportable(_ error: any Error) -> Bool {
        if error is CancellationError || error is AuthenticationError {
            return false
        }
        if let urlError = error as? URLError {
            return !Excluded.urlErrorCodes.contains(urlError.code)
        }
        return true
    }
}

private enum TypeName {
    static let urlError = "URLError"
}

private enum Excluded {
    /// 취소와 오프라인류. 사용자가 다시 시도하면 되는 에러다.
    static let urlErrorCodes: Set<URLError.Code> = [
        .cancelled,
        .notConnectedToInternet,
        .networkConnectionLost,
        .dataNotAllowed,
        .internationalRoamingOff,
    ]
}
