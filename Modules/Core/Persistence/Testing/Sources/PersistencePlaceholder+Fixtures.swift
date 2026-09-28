//
//  PersistencePlaceholder+Fixtures.swift
//  PersistenceTesting
//

import Persistence

/// 다른 모듈의 테스트·데모가 쓰는 픽스처. 복붙하지 않고 `.testing(.core("Persistence"))` 로 가져간다.
public extension PersistencePlaceholder {
    static let sample = PersistencePlaceholder()
}
