import FlyingFox
import SQLite
import SwiftUI

@main
struct MyApp: App {
    init() {
        //setenv("RUST_LOG", "trace", 1)
        //set_debug(true)
        Task.detached {
            Utils.port = try Utils.reservePort()
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let d28LocalPath = documentsDirectory.appendingPathComponent("downloads.28.sqlitedb").path
            let bldLocalPath = documentsDirectory.appendingPathComponent("BLDatabaseManager.sqlite").path
            
            // copy files from bundle to Documents folder
            let bundle = Bundle.main
            if !FileManager.default.fileExists(atPath: d28LocalPath),
               let resourcePath = bundle.path(forResource: "downloads.28", ofType: "sqlitedb") {
                try FileManager.default.copyItem(atPath: resourcePath, toPath: d28LocalPath)
            }
            if !FileManager.default.fileExists(atPath: bldLocalPath),
               let resourcePath = bundle.path(forResource: "BLDatabaseManager", ofType: "sqlite") {
                try FileManager.default.copyItem(atPath: resourcePath, toPath: bldLocalPath)
            }
            if !FileManager.default.fileExists(atPath: bldLocalPath + "-shm"),
                let resourcePath = bundle.path(forResource: "BLDatabaseManager", ofType: "sqlite-shm") {
                try FileManager.default.copyItem(atPath: resourcePath, toPath: bldLocalPath + "-shm")
            }
            if !FileManager.default.fileExists(atPath: bldLocalPath + "-wal"),
                let resourcePath = bundle.path(forResource: "BLDatabaseManager", ofType: "sqlite-wal") {
                try FileManager.default.copyItem(atPath: resourcePath, toPath: bldLocalPath + "-wal")
            }
            
            print("WARNING: Hardcoded UUID!!!")
            let uuid = "6F7F5114-0F95-4B08-B8F5-80A049C84E09"
            try Databases.patchDatabase(dbPath: d28LocalPath, uuid: uuid, ip: "localhost", port: Utils.port)
            
            let server = HTTPServer(port: Utils.port)
            await server.appendRoute("GET /*", to: DirectoryHTTPHandler(root: documentsDirectory))
            try await server.run()
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
