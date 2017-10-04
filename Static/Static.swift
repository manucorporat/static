//
//  Static.swift
//  Static
//
//  Created by Manuel Martinez-Almeida on 28/09/2017.
//  Copyright © 2017 Manuel Martinez-Almeida. All rights reserved.
//

import Foundation
import Embassy
import MobileCoreServices

struct StaticRequest {
    let start: CFAbsoluteTime
    let end: CFAbsoluteTime
    let path: String
    let fileSize: UInt64
    let range: Range<UInt64>?
}

typealias StartResponse = ((String, [(String, String)]) -> Void)
typealias SendBody = ((Data) -> Void)

public class Static {
    let baseURL: URL
    let port: Int
    var log: [StaticRequest] = []
    
    init(basePath: String, port: Int) {
        self.baseURL = URL(fileURLWithPath: basePath, isDirectory: true)
        self.port = port
    }
    
    func start() {
        let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
        let server = DefaultHTTPServer(eventLoop: loop, port: self.port) {
            (environ: [String: Any], startResponse: StartResponse, sendBody: SendBody) in
            let path = environ["PATH_INFO"]! as! String
            let range = environ["HTTP_RANGE"]! as! String
            self.handleFile(startResponse, sendBody, path, range)
            sendBody(Data())
        }
        
        // Start HTTP server to listen on the port
        try! server.start()
        
        // Run event loop
        loop.runForever()
    }
    
    func handleFile(_ startResponse: StartResponse, _ sendBody: SendBody, _ path: String, _ range: String) {
        let absolutePath = baseURL.appendingPathComponent(path).absoluteString
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let attr = try FileManager.default.attributesOfItem(atPath: absolutePath)
            let fileSize = attr[FileAttributeKey.size] as! UInt64
            let fileType = attr[FileAttributeKey.type] as! FileAttributeType
            var offset: UInt64 = 0
            var size: UInt64 = fileSize
            
            if fileType != FileAttributeType.typeRegular {
                return;
            }
            
            var code = "200 OK"
            var header: [(String, String)] = [
                ("ContentType", mimeForExtension(ext: path, overrides: nil)),
                ("LastModifiedDate", ""),
                ("ETag", ""),
            ]
            let ra = self.parseRange(fileSize: fileSize, range: "")

            if let r = ra {
                code = "206"
                offset = r.lowerBound
                size = UInt64(r.count)
                let value = String(format: "bytes %lu-%ly/%lu", UInt64(offset), UInt64(offset + size - 1), UInt64(fileSize))
                header.append(("Content-Range", value))
            }
            header.append(("ContentLength", String(size)))
            
            startResponse(code, header)
            if let file = FileHandle(forReadingAtPath: path) {
                file.seek(toFileOffset: offset)
                sendBody(file.readData(ofLength: Int(size)))
                
                self.log.append(StaticRequest(
                    start: startTime,
                    end: CFAbsoluteTimeGetCurrent(),
                    path: path,
                    fileSize: fileSize,
                    range: nil
                ))
            }
        } catch {
            
        }
    }
    
    func mimeForExtension(ext: String, overrides: [String: String]?) -> String {
        let builtInOverrides = [ "css" : "text/css" ]
        var mimeType: String?
        let normalizedExt = ext.lowercased()
        if (normalizedExt.count > 0) {
            mimeType = overrides?[normalizedExt];
            if (mimeType == nil) {
                mimeType = builtInOverrides[normalizedExt];
            }
            if (mimeType == nil) {
                let ref = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, normalizedExt as CFString, nil)
                if let uti = ref {
                    mimeType = UTTypeCopyPreferredTagWithClass(uti.takeUnretainedValue(), kUTTagClassMIMEType)?.takeRetainedValue() as String?
                    uti.release()
                }
            }
        }
        return mimeType != nil ? mimeType! : "application/octet-stream";
    }
    
    func parseRange(fileSize: UInt64, r: String?) -> Range<Int>? {
        
        let byteRange = Range(uncheckedBounds: (lower: 0, upper: 0))
        if let range = r {
            let rangeHeader = normalizeHeaderValue(range);
            if !rangeHeader.hasPrefix("bytes=") {
                return byteRange
            }
            let components = rangeHeader[6..<rangeHeader.endIndex]
            
            
            switch components.count {
            case 1:
            case 2:
                
            }
//            if ([rangeHeader hasPrefix:@"bytes="]) {
//                NSArray* components = [[rangeHeader substringFromIndex:6] componentsSeparatedByString:@","];
//                if (components.count == 1) {
//                    components = [[components firstObject] componentsSeparatedByString:@"-"];
//                    if (components.count == 2) {
//                        NSString* startString = [components objectAtIndex:0];
//                        NSInteger startValue = [startString integerValue];
//                        NSString* endString = [components objectAtIndex:1];
//                        NSInteger endValue = [endString integerValue];
//                        if (startString.length && (startValue >= 0) && endString.length && (endValue >= startValue)) {  // The second 500 bytes: "500-999"
//                            _byteRange.location = startValue;
//                            _byteRange.length = endValue - startValue + 1;
//                        } else if (startString.length && (startValue >= 0)) {  // The bytes after 9500 bytes: "9500-"
//                            _byteRange.location = startValue;
//                            _byteRange.length = NSUIntegerMax;
//                        } else if (endString.length && (endValue > 0)) {  // The final 500 bytes: "-500"
//                            _byteRange.location = NSUIntegerMax;
//                            _byteRange.length = endValue;
//                        }
//                    }
//                }
//            }
//            if ((_byteRange.location == NSUIntegerMax) && (_byteRange.length == 0)) {  // Ignore "Range" header if syntactically invalid
//                GWS_LOG_WARNING(@"Failed to parse 'Range' header \"%@\" for url: %@", rangeHeader, url);
//            }
        }

        return 0..<fileSize

    }
    
    func normalizeHeaderValue(_ value: String) -> String {
        return value
    }
    //        BOOL hasByteRange = GCDWebServerIsValidByteRange(range);
    //        if (hasByteRange) {
    //            if (range.location != NSUIntegerMax) {
    //                range.location = MIN(range.location, fileSize);
    //                range.length = MIN(range.length, fileSize - range.location);
    //            } else {
    //                range.length = MIN(range.length, fileSize);
    //                range.location = fileSize - range.length;
    //            }
    //            if (range.length == 0) {
    //                return nil;  // TODO: Return 416 status code and "Content-Range: bytes */{file length}" header
    //            }
    //        } else {
    //            range.location = 0;
    //            range.length = fileSize;
    //        }
}

//NSString* GCDWebServerNormalizeHeaderValue(NSString* value) {
//    if (value) {
//        NSRange range = [value rangeOfString:@";"];  // Assume part before ";" separator is case-insensitive
//        if (range.location != NSNotFound) {
//            value = [[[value substringToIndex:range.location] lowercaseString] stringByAppendingString:[value substringFromIndex:range.location]];
//        } else {
//            value = [value lowercaseString];
//        }
//    }
//    return value;
//}



