import SwiftPizzaSnips

extension S3Controller: Withable {}
extension S3Owner: Withable {}
extension S3ObjectVersionDeleteMarker: Withable {}
extension S3ObjectVersion: Withable {}
extension S3ObjectIdentifier: Withable {}
extension S3ListObjectVersionsResult: Withable {}
extension S3ListBucketResult: Withable {}
extension S3Folder: Withable {}

import XMLCoder
extension XMLDecoder: @retroactive Withable {}
extension XMLEncoder: @retroactive Withable {}
