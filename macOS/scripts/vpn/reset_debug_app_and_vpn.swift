import Foundation

// NOTE: Requires root privileges to run

// Execute a shell command
func runCommand(_ command: String, arguments: [String] = []) {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = [command] + arguments
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    do {
        try process.run()
        process.waitUntilExit()
        print("\(command) executed successfully.")
    } catch {
        print("Error executing \(command): \(error)")
    }
}

// Find and terminate a process using part of its bundle identifier
func terminateProcess(matching keyword: String) {
    let process = Process()
    let pipe = Pipe()

    process.launchPath = "/bin/bash"
    process.arguments = ["-c", "ps aux | grep '\(keyword)' | grep -v grep"]
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            print("No running process found for keyword: \(keyword).")
            return
        }

        let lines = output.split(separator: "\n")
        for line in lines {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            let pidString = columns[1]
            if let pid = Int(pidString) {
                runCommand("kill", arguments: ["-9", String(pid)])
                print("Terminated process with keyword '\(keyword)' and PID \(pid).")
            }
        }

    } catch {
        print("Error finding process with keyword \(keyword): \(error)")
    }
}

// Function to delete a folder in ~/Applications
func deleteFolder(named folderName: String) {
    let folderPath = URL(fileURLWithPath: "/Applications")
        .appendingPathComponent(folderName)
        .path

    print("Attempting to delete \(folderPath) as root...")
    runCommand("rm", arguments: ["-rf", folderPath])
}


deleteFolder(named: "DEBUG")

// Resetting system network extension
runCommand("systemextensionsctl", arguments: ["reset"])

// Terminate specified processes
terminateProcess(matching: "com.duckduckgo.macos.vpn")
terminateProcess(matching: "com.duckduckgo.macos.browser.network-protection.notifications")
