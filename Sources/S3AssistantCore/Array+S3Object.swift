import Foundation

public extension Array where Element == S3Object {
	func deleteList(quiet: Bool = false) throws -> XMLDocument {
		guard count <= 1000 else { throw ArrayError.moreThan1000Objects }

		let doc = XMLDocument(kind: .document)
		let attribute = XMLNode(kind: .attribute)
		attribute.name = "xmlns"
		attribute.stringValue = "http://s3.amazonaws.com/doc/2006-03-01/"
		let deleteElement = XMLElement(name: "Delete")
		deleteElement.addAttribute(attribute)
		doc.addChild(deleteElement)

		let quietElement = XMLElement(name: "Quiet", stringValue: "\(quiet)")
		deleteElement.addChild(quietElement)

		for item in self {
			let objectElement = XMLElement(name: "Object")
			let	keyElement = XMLElement(name: "Key", stringValue: item.key)
			objectElement.addChild(keyElement)
			deleteElement.addChild(objectElement)
		}

		return doc
	}

	enum ArrayError: Error {
		case moreThan1000Objects
	}
}

public extension Array where Element == S3Object {
	var prettyPrinted: String {
		"""
		[
		\(self.map(\.description).joined(separator: ",\n").addIndentation(count: 1))
		]
		"""
	}
}
