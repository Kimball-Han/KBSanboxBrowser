import Foundation
import GCDWebServer
import SQLite3

public class KBSandboxBrowser {
    public static let shared = KBSandboxBrowser()
    
    private let webServer = GCDWebServer()
    private var isRunning = false
    
    private init() {
    }
    
    public func start(port: UInt = 9906) {
        guard !isRunning else { return }
        
        webServer.removeAllHandlers()
        
        // Serve Web Assets
        if let bundlePath = Bundle(for: KBSandboxBrowser.self).path(forResource: "KBSanboxBrowser", ofType: "bundle"),
           let bundle = Bundle(path: bundlePath),
           let webPath = bundle.path(forResource: "dist", ofType: nil) {
            webServer.addGETHandler(forBasePath: "/", directoryPath: webPath, indexFilename: "index.html", cacheAge: 3600, allowRangeRequests: true)
        } else {
            print("KBSandboxBrowser: Web assets not found. Please build the Vue app and place 'dist' in Assets.")
        }
        
        setupHandlers()
        
        webServer.start(withPort: port, bonjourName: "KBSandboxBrowser")
        print("KBSandboxBrowser started at \(webServer.serverURL?.absoluteString ?? "")")
        isRunning = true
    }
    
    public var serverURL: URL? {
        if let ip = getIPAddress() {
            let port = webServer.port
            return URL(string: "http://\(ip):\(port)/")
        }
        return webServer.serverURL
    }
    
    public func stop() {
        webServer.stop()
        isRunning = false
    }
    
    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
    
    private func setupHandlers() {
        // List Files
        webServer.addHandler(forMethod: "GET", path: "/api/list", request: GCDWebServerRequest.self) { [weak self] request in
            guard let self = self else { return GCDWebServerResponse(statusCode: 500) }
            let query = request.query ?? [:]
            let path = query["path"] ?? "/"
            return self.handleListFiles(path: path)
        }
        
        // Create Folder
        webServer.addHandler(forMethod: "POST", path: "/api/create_folder", request: GCDWebServerURLEncodedFormRequest.self) { [weak self] request in
            guard let self = self else { return GCDWebServerResponse(statusCode: 500) }
            let formRequest = request as! GCDWebServerURLEncodedFormRequest
            let path = formRequest.arguments["path"] ?? ""
            return self.handleCreateFolder(path: path)
        }
        
        // Delete File/Folder
        webServer.addHandler(forMethod: "POST", path: "/api/delete", request: GCDWebServerURLEncodedFormRequest.self) { [weak self] request in
            guard let self = self else { return GCDWebServerResponse(statusCode: 500) }
            let formRequest = request as! GCDWebServerURLEncodedFormRequest
            let path = formRequest.arguments["path"] ?? ""
            return self.handleDelete(path: path)
        }
        
        // Rename File/Folder
        webServer.addHandler(forMethod: "POST", path: "/api/rename", request: GCDWebServerURLEncodedFormRequest.self) { [weak self] request in
            guard let self = self else { return GCDWebServerResponse(statusCode: 500) }
            let formRequest = request as! GCDWebServerURLEncodedFormRequest
            let path = formRequest.arguments["path"] ?? ""
            let newName = formRequest.arguments["newName"] ?? ""
            return self.handleRename(path: path, newName: newName)
        }
        
        // Upload File
        webServer.addHandler(forMethod: "POST", path: "/api/upload", request: GCDWebServerMultiPartFormRequest.self) { [weak self] request in
            guard let self = self else { return GCDWebServerResponse(statusCode: 500) }
            let multiPartRequest = request as! GCDWebServerMultiPartFormRequest
            return self.handleUpload(request: multiPartRequest)
        }
        
        // Download/View File
        webServer.addHandler(forMethod: "GET", path: "/api/file", request: GCDWebServerRequest.self) { [weak self] request in
            guard let self = self else { return GCDWebServerResponse(statusCode: 500) }
            let query = request.query ?? [:]
            let path = query["path"] ?? ""
            return self.handleDownload(path: path)
        }
        
        // Query Database
        webServer.addHandler(forMethod: "POST", path: "/api/query_db", request: GCDWebServerDataRequest.self) { [weak self] request in
            guard let self = self else { return GCDWebServerResponse(statusCode: 500) }
            let dataRequest = request as! GCDWebServerDataRequest
            
            var arguments: [String: String] = [:]
            // Use URLComponents to parse the query string safely from data
            if let queryString = String(data: dataRequest.data, encoding: .utf8) {
                var components = URLComponents()
                components.percentEncodedQuery = queryString
                components.queryItems?.forEach { item in
                    if let value = item.value {
                        arguments[item.name] = value
                    }
                }
            }
            
            let path = arguments["path"] ?? ""
            let sql = arguments["sql"] ?? ""
            print("KBSandboxBrowser: Query DB path: \(path), sql: \(sql)")
            return self.handleQueryDB(path: path, sql: sql)
        }
    }
    
    // MARK: - Handlers
    
    private func createJSONResponse(_ data: [String: Any], statusCode: Int = 200) -> GCDWebServerResponse {
        if let response = GCDWebServerDataResponse(jsonObject: data) {
            response.statusCode = statusCode
            return response
        }
        return GCDWebServerResponse(statusCode: 500)
    }
    
    private func getAbsolutePath(for path: String) -> String {
        let home = NSHomeDirectory()
        if path == "/" || path.isEmpty {
            return home
        }
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return (home as NSString).appendingPathComponent(relativePath)
    }
    
    private func handleListFiles(path: String) -> GCDWebServerResponse {
        let fullPath = getAbsolutePath(for: path)
        print("KBSandboxBrowser: Listing files at \(fullPath)")
        
        var isDir: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else {
            print("KBSandboxBrowser: Directory not found at \(fullPath)")
            return createJSONResponse(["error": "Directory not found"], statusCode: 404)
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: fullPath)
            let files = try contents.compactMap { fileName -> [String: Any]? in
                // Permission check: Hide SystemData and .plist files in root directory
                if path == "/" || path.isEmpty {
                    if fileName == "SystemData" || fileName.hasSuffix(".plist") {
                        return nil
                    }
                }
                
                let filePath = (fullPath as NSString).appendingPathComponent(fileName)
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                let type = (attributes[.type] as? FileAttributeType) == .typeDirectory ? "directory" : "file"
                let size = attributes[.size] as? Int64 ?? 0
                return [
                    "name": fileName,
                    "type": type,
                    "size": size,
                    "path": (path as NSString).appendingPathComponent(fileName)
                ]
            }
            return createJSONResponse(["files": files])
        } catch {
            return createJSONResponse(["error": error.localizedDescription], statusCode: 500)
        }
    }
    
    private func handleCreateFolder(path: String) -> GCDWebServerResponse {
        // Permission check: Prevent creating folders in root directory
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if !cleanPath.contains("/") {
            return createJSONResponse(["error": "Creating folders in root directory is not allowed"], statusCode: 403)
        }
        
        let fullPath = getAbsolutePath(for: path)
        do {
            try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: nil)
            return createJSONResponse(["success": true])
        } catch {
            return createJSONResponse(["error": error.localizedDescription], statusCode: 500)
        }
    }
    
    private func handleRename(path: String, newName: String) -> GCDWebServerResponse {
        guard !path.isEmpty, !newName.isEmpty else {
             return createJSONResponse(["error": "Invalid parameters"], statusCode: 400)
        }
        
        let fullPath = getAbsolutePath(for: path)
        
        // Permission check: Prevent renaming items in root directory
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if !cleanPath.contains("/") {
             return createJSONResponse(["error": "Renaming items in root directory is not allowed"], statusCode: 403)
        }

        let parentPath = (fullPath as NSString).deletingLastPathComponent
        let newFullPath = (parentPath as NSString).appendingPathComponent(newName)
        
        do {
            try FileManager.default.moveItem(atPath: fullPath, toPath: newFullPath)
            return createJSONResponse(["success": true])
        } catch {
            return createJSONResponse(["error": error.localizedDescription], statusCode: 500)
        }
    }
    
    private func handleDelete(path: String) -> GCDWebServerResponse {
        let fullPath = getAbsolutePath(for: path)
        
        // Permission check: Prevent deleting folders in root directory
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if !cleanPath.contains("/") {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                return createJSONResponse(["error": "Deleting folders in root directory is not allowed"], statusCode: 403)
            }
        }
        
        do {
            try FileManager.default.removeItem(atPath: fullPath)
            return createJSONResponse(["success": true])
        } catch {
            return createJSONResponse(["error": error.localizedDescription], statusCode: 500)
        }
    }
    
    private func handleUpload(request: GCDWebServerMultiPartFormRequest) -> GCDWebServerResponse {
        guard let file = request.files.first,
              let pathArgument = request.firstArgument(forControlName: "path"),
              let path = pathArgument.string else {
            return createJSONResponse(["error": "Invalid request"], statusCode: 400)
        }
        
        // Permission check: Prevent uploading files to root directory
        if path == "/" || path.isEmpty {
            return createJSONResponse(["error": "Uploading files to root directory is not allowed"], statusCode: 403)
        }
        
        let fullDirPath = getAbsolutePath(for: path)
        let fullFilePath = (fullDirPath as NSString).appendingPathComponent(file.fileName)
        
        do {
            if FileManager.default.fileExists(atPath: fullFilePath) {
                try FileManager.default.removeItem(atPath: fullFilePath)
            }
            try FileManager.default.moveItem(atPath: file.temporaryPath, toPath: fullFilePath)
            return createJSONResponse(["success": true])
        } catch {
            return createJSONResponse(["error": error.localizedDescription], statusCode: 500)
        }
    }
    
    private func handleDownload(path: String) -> GCDWebServerResponse {
        let fullPath = getAbsolutePath(for: path)
        if let response = GCDWebServerFileResponse(file: fullPath) {
            return response
        } else {
            return createJSONResponse(["error": "File not found"], statusCode: 404)
        }
    }
    
    private func handleQueryDB(path: String, sql: String) -> GCDWebServerResponse {
        let fullPath = getAbsolutePath(for: path)
        
        var db: OpaquePointer?
        // Open in read-only mode to prevent creating empty files
        guard sqlite3_open_v2(fullPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            return createJSONResponse(["error": "Could not open database: \(errorMsg)"], statusCode: 500)
        }
        defer { sqlite3_close(db) }
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            return createJSONResponse(["error": errorMsg], statusCode: 400)
        }
        defer { sqlite3_finalize(statement) }
        
        var columns: [String] = []
        let columnCount = sqlite3_column_count(statement)
        for i in 0..<columnCount {
            if let name = sqlite3_column_name(statement, i) {
                columns.append(String(cString: name))
            } else {
                columns.append("Column \(i)")
            }
        }
        
        var rows: [[String: Any]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<columnCount {
                let name = columns[Int(i)]
                let type = sqlite3_column_type(statement, i)
                
                var value: Any = NSNull()
                switch type {
                case SQLITE_INTEGER:
                    value = sqlite3_column_int64(statement, i)
                case SQLITE_FLOAT:
                    value = sqlite3_column_double(statement, i)
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(statement, i) {
                        value = String(cString: UnsafeRawPointer(text).assumingMemoryBound(to: CChar.self))
                    }
                case SQLITE_BLOB:
                    value = "<BLOB>"
                case SQLITE_NULL:
                    value = NSNull()
                default:
                    value = NSNull()
                }
                row[name] = value
            }
            rows.append(row)
        }
        
        return createJSONResponse(["columns": columns, "rows": rows])
    }
}
