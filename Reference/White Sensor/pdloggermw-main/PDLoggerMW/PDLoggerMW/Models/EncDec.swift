//
//  EncDec.swift
//  PDLoggerMW
//
//  Created by Jiun Shiah Low on 13/11/24.
//

import CommonCrypto

struct EncDec
{
    static func SHA512(_ str: String) -> String {
     
        if let strData = str.data(using: String.Encoding.utf8) {
            /// #define CC_SHA512_DIGEST_LENGTH     64
            /// Creates an array of unsigned 8 bit integers that contains 64 zeros
            var digest = [UInt8](repeating: 0, count:Int(CC_SHA512_DIGEST_LENGTH))
            Utils.log("digest length: \(digest.count)")
            /// CC_SHA512 performs digest calculation and places the result in the caller-supplied buffer for digest (md)
            /// Takes the strData referenced value (const unsigned char *d) and hashes it into a reference to the digest parameter.
            _ = strData.withUnsafeBytes {
                // CommonCrypto
                // extern unsigned char *CC_SHA512(const void *data, CC_LONG len, unsigned char *md)  -|
                // OpenSSL                                                                             |
                // unsigned char *SHA512(const unsigned char *d, size_t n, unsigned char *md)        <-|
                CC_SHA512($0.baseAddress, UInt32(strData.count), &digest)
            }
            return digest.map { String(format: "%02x", $0) }.joined()
        }
        return ""
    }
}
