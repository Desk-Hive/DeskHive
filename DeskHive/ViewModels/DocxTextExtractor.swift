//
//  DocxTextExtractor.swift
//  DeskHive
//
//  Extracts plain text from a .docx (ZIP) file using zlib for raw deflate.
//  No third-party dependencies — zlib ships on every iOS device.
//

import Foundation
import zlib

enum DocxExtractError: Error, LocalizedError {
    case notAZip
    case documentXmlNotFound
    case decompressionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAZip:                    return "Not a valid ZIP/docx file."
        case .documentXmlNotFound:        return "word/document.xml not found inside the docx."
        case .decompressionFailed(let r): return "Decompression failed: \(r)"
        }
    }
}

struct DocxTextExtractor {

    // MARK: - Public API

    static func extractText(from data: Data) throws -> String {
        let xmlData = try unzipEntry(named: "word/document.xml", from: data)
        guard let xml = String(data: xmlData, encoding: .utf8) else {
            throw DocxExtractError.decompressionFailed("UTF-8 decode failed")
        }
        return extractTextFromXML(xml)
    }

    static func chunk(text: String, maxWords: Int = 400, overlap: Int = 40) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        var chunks: [String] = []
        var start = 0
        while start < words.count {
            let end = min(start + maxWords, words.count)
            chunks.append(words[start..<end].joined(separator: " "))
            if end == words.count { break }
            start += maxWords - overlap
        }
        return chunks
    }

    // MARK: - ZIP parser

    private static let eocdSig:    UInt32 = 0x06054b50
    private static let centralSig: UInt32 = 0x02014b50

    private static func unzipEntry(named target: String, from data: Data) throws -> Data {
        let count = data.count
        guard count >= 22 else { throw DocxExtractError.notAZip }

        // 1. Find EOCD scanning backwards
        var eocdPos = -1
        let limit = max(0, count - 22 - 65535)
        for i in stride(from: count - 22, through: limit, by: -1) {
            if data.u32le(at: i) == eocdSig { eocdPos = i; break }
        }
        guard eocdPos >= 0 else { throw DocxExtractError.notAZip }

        let cdCount  = Int(data.u16le(at: eocdPos + 8))
        var cdOffset = Int(data.u32le(at: eocdPos + 16))

        // 2. Walk Central Directory
        for _ in 0..<cdCount {
            guard cdOffset + 46 <= count,
                  data.u32le(at: cdOffset) == centralSig else { break }

            let method         = Int(data.u16le(at: cdOffset + 10))
            let compSize       = Int(data.u32le(at: cdOffset + 20))
            let uncompSize     = Int(data.u32le(at: cdOffset + 24))
            let nameLen        = Int(data.u16le(at: cdOffset + 28))
            let extraLen       = Int(data.u16le(at: cdOffset + 30))
            let commentLen     = Int(data.u16le(at: cdOffset + 32))
            let localHdrOffset = Int(data.u32le(at: cdOffset + 42))

            let nameEnd = cdOffset + 46 + nameLen
            guard nameEnd <= count else { break }
            let name = String(data: data[(cdOffset + 46) ..< nameEnd], encoding: .utf8) ?? ""

            if name == target {
                // Local file header has its own extra-field length
                let localNameLen  = Int(data.u16le(at: localHdrOffset + 26))
                let localExtraLen = Int(data.u16le(at: localHdrOffset + 28))
                let dataStart     = localHdrOffset + 30 + localNameLen + localExtraLen

                guard dataStart >= 0, dataStart + compSize <= count else {
                    throw DocxExtractError.decompressionFailed("data out of bounds")
                }

                let compressed = data[dataStart ..< dataStart + compSize]
                if method == 0 { return Data(compressed) }
                guard method == 8 else {
                    throw DocxExtractError.decompressionFailed("unsupported method \(method)")
                }
                return try rawInflate(Data(compressed), expectedSize: uncompSize)
            }

            cdOffset += 46 + nameLen + extraLen + commentLen
        }
        throw DocxExtractError.documentXmlNotFound
    }

    // MARK: - Raw deflate via zlib (method = -15 means no wrapper)

    private static func rawInflate(_ input: Data, expectedSize: Int) throws -> Data {
        var outSize = max(expectedSize * 3, 65536)
        var output  = Data(count: outSize)

        let zlibResult: Int32 = input.withUnsafeBytes { srcBuf in
            output.withUnsafeMutableBytes { dstBuf in
                guard let src = srcBuf.baseAddress,
                      let dst = dstBuf.baseAddress else { return Z_DATA_ERROR }

                var stream         = z_stream()
                stream.next_in     = UnsafeMutablePointer(mutating: src.assumingMemoryBound(to: Bytef.self))
                stream.avail_in    = uInt(input.count)
                stream.next_out    = dst.assumingMemoryBound(to: Bytef.self)
                stream.avail_out   = uInt(outSize)

                // -15 = raw deflate, no zlib/gzip wrapper
                guard inflateInit2_(&stream, -15, ZLIB_VERSION,
                                    Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                    return Z_STREAM_ERROR
                }
                let status = inflate(&stream, Z_FINISH)
                outSize    = Int(stream.total_out)
                inflateEnd(&stream)
                return status
            }
        }

        guard (zlibResult == Z_STREAM_END || zlibResult == Z_OK), outSize > 0 else {
            throw DocxExtractError.decompressionFailed("zlib code \(zlibResult)")
        }
        output.count = outSize
        return output
    }

    // MARK: - XML → plain text (targets <w:t> runs, <w:p> paragraph breaks)

    private static func extractTextFromXML(_ xml: String) -> String {
        var result = ""
        var i = xml.startIndex
        let end = xml.endIndex

        while i < end {
            guard let tagOpen = xml[i...].firstIndex(of: "<") else { break }
            guard let tagClose = xml[tagOpen...].firstIndex(of: ">") else { break }

            let tagContent = xml[xml.index(after: tagOpen) ..< tagClose]
            // Tag name is everything up to first space or '/'
            let tagName = tagContent.split(maxSplits: 1,
                                           whereSeparator: { $0 == " " || $0 == "/" }).first
                                    .map(String.init) ?? ""

            switch tagName {
            case "w:p", "w:br", "w:tr":
                result += "\n"
            case "w:t":
                // Grab text up to </w:t>
                let after = xml.index(after: tagClose)
                if let closeRange = xml[after...].range(of: "</w:t>") {
                    result += String(xml[after ..< closeRange.lowerBound])
                    i = closeRange.upperBound
                    continue
                }
            default:
                break
            }
            i = xml.index(after: tagClose)
        }

        // Collapse whitespace
        return result
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// MARK: - Data little-endian helpers (safe unaligned reads)

private extension Data {
    func u16le(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        var val: UInt16 = 0
        _ = Swift.withUnsafeMutableBytes(of: &val) { dst in
            self.copyBytes(to: dst, from: offset ..< offset + 2)
        }
        return val.littleEndian
    }
    func u32le(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        var val: UInt32 = 0
        _ = Swift.withUnsafeMutableBytes(of: &val) { dst in
            self.copyBytes(to: dst, from: offset ..< offset + 4)
        }
        return val.littleEndian
    }
}
