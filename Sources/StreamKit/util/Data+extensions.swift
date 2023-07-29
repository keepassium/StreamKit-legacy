//  StreamKit
//  Copyright © 2023 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

extension Data {
    /// Returns data contents as hex string. (From https://stackoverflow.com/a/40089462)
    public var asHexString: String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var chars: [unichar] = []
        chars.reserveCapacity(2 * count)
        self.withUnsafeBytes { bytes in
            for byte in bytes {
                chars.append(hexDigits[Int(byte / 16)])
                chars.append(hexDigits[Int(byte % 16)])
                chars.append(contentsOf: " ".utf16)
            }
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}
