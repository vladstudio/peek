import CoreGraphics

enum RegionPreset: String, CaseIterable, Identifiable {
    case leftHalf = "Left Half"
    case rightHalf = "Right Half"
    case centerHalf = "Center Half"
    case leftThird = "Left Third"
    case rightThird = "Right Third"
    case centerThird = "Center Third"

    var id: String { rawValue }

    func sourceRect(displayWidth: Int, displayHeight: Int) -> CGRect {
        let w = CGFloat(displayWidth)
        let h = CGFloat(displayHeight)
        switch self {
        case .leftHalf:    return CGRect(x: 0, y: 0, width: w / 2, height: h)
        case .rightHalf:   return CGRect(x: w / 2, y: 0, width: w / 2, height: h)
        case .centerHalf:  return CGRect(x: w / 4, y: 0, width: w / 2, height: h)
        case .leftThird:   return CGRect(x: 0, y: 0, width: w / 3, height: h)
        case .rightThird:  return CGRect(x: w * 2 / 3, y: 0, width: w / 3, height: h)
        case .centerThird: return CGRect(x: w / 3, y: 0, width: w / 3, height: h)
        }
    }

    func regionSize(displayWidth: Int, displayHeight: Int) -> (width: Int, height: Int) {
        switch self {
        case .leftHalf, .rightHalf, .centerHalf:
            return (displayWidth / 2, displayHeight)
        case .leftThird, .rightThird, .centerThird:
            return (displayWidth / 3, displayHeight)
        }
    }
}
