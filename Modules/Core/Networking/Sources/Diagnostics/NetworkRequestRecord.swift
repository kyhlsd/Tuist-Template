//
//  NetworkRequestRecord.swift
//  Networking
//

/// 끝난 요청 하나의 요약. 요청 로그와 같은 규칙으로 헤더·바디·쿼리는 담지 않는다.
public struct NetworkRequestRecord: Sendable, Equatable {
    /// HTTP method. 예: `GET`.
    public let method: String
    /// 쿼리를 뺀 path.
    public let path: String
    /// 응답 status. 실패하면 `nil`.
    public let statusCode: Int?
    /// 실패 요약(`NetworkFailure.summary`). 성공하면 `nil`.
    public let failureSummary: String?
    /// 취소로 끝났는지. 취소는 실패 요약이 있어도 실패로 다루지 않는다.
    public let isCancellation: Bool
    /// 재시도를 포함한 전체 소요 시간.
    public let elapsedMilliseconds: Int64
    /// 요청 헤더의 request ID. 없으면 `nil`.
    public let requestID: String?

    public init(
        method: String,
        path: String,
        statusCode: Int?,
        failureSummary: String?,
        isCancellation: Bool,
        elapsedMilliseconds: Int64,
        requestID: String?
    ) {
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.failureSummary = failureSummary
        self.isCancellation = isCancellation
        self.elapsedMilliseconds = elapsedMilliseconds
        self.requestID = requestID
    }
}
