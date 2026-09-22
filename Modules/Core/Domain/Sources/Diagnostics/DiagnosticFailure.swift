//
//  DiagnosticFailure.swift
//  Domain
//

/// 클라이언트가 보고할 실패 하나. 서버가 볼 수 없는 에러만 담는다.
///
/// 모든 필드는 요약값이다. 에러 설명에는 URL 이 들어갈 수 있으므로 담지 않는다.
public struct DiagnosticFailure: Sendable, Equatable {
    /// 실패한 operation. 알 수 없으면 `nil`.
    public let operationID: String?
    /// 원래 에러의 타입 이름. 예: `URLError`.
    public let errorType: String
    /// 에러 코드(`URLError` 코드 등). 없으면 `nil`.
    public let errorCode: Int?
    /// 사람이 읽는 한 단어 요약. 예: `URLError(-1004)`.
    public let summary: String
    /// 서버 로그와 잇는 request ID. 서버가 받지 못한 요청이면 `nil`.
    public let requestID: String?

    public init(operationID: String?, errorType: String, errorCode: Int?, summary: String, requestID: String?) {
        self.operationID = operationID
        self.errorType = errorType
        self.errorCode = errorCode
        self.summary = summary
        self.requestID = requestID
    }

    /// 같은 에러인지 가르는 키. operation, 타입, 코드로만 정한다.
    ///
    /// `summary` 와 `requestID` 는 요청마다 달라질 수 있어서 넣지 않는다.
    public var fingerprint: String {
        [
            operationID ?? Fingerprint.missing,
            errorType,
            errorCode.map(String.init) ?? Fingerprint.missing,
        ].joined(separator: Fingerprint.separator)
    }
}

private enum Fingerprint {
    static let missing = "-"
    static let separator = "|"
}
