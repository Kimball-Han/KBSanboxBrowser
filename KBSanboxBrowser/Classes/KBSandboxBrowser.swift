import Foundation
import GCDWebServer

public class KBSandboxBrowser {
    public static let shared = KBSandboxBrowser()
    
    private let webServer = GCDWebServer()
    private var isRunning = false
    
    private init() {
    }
    
    public func start(port: UInt = 8080) {
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
        return webServer.serverURL
    }
    
    public func stop() {
        webServer.stop()
        isRunning = false
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
        guard let file = request.files.first as? GCDWebServerMultiPartFile,
              let pathArgument = request.firstArgument(forControlName: "path"),
              let path = pathArgument.string else {
            return createJSONResponse(["error": "Invalid request"], statusCode: 400)
        }
        
        // Permission check: Prevent uploading files to root directory
        if path == "/" || path.isEmpty {
            return createJSONResponse(["error": "Uploading files to root directory is not allowed"], statusCode: 403)
        }
        
        let fullDirPath = getAbsolutePath(for: path)
        let fullFilePath = (fullDirPath as NSString).appendingPathComponent(file.fileName ?? "uploaded_file")
        
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
}
