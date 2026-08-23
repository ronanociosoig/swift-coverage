/// A plain data type: swift-coverage should find zero logic units here, so
/// it's never asked to be "covered" in the first place.
public struct Order {
    public let id: String
    public let itemCount: Int
    public let isFirstOrder: Bool

    public init(id: String, itemCount: Int, isFirstOrder: Bool) {
        self.id = id
        self.itemCount = itemCount
        self.isFirstOrder = isFirstOrder
    }
}
