import Foundation

public actor SystemImageService {
    private let sdk: AndroidSDK

    public init(sdk: AndroidSDK) {
        self.sdk = sdk
    }

    public func listImages() async throws -> [SystemImage] {
        guard let sdkmanager = await sdk.sdkmanagerPath else {
            throw AVDManagerError.missingSDK
        }
        let env = await sdk.environmentForSubprocess()
        let result = try await ProcessRunner.run(
            sdkmanager,
            arguments: ["--list"],
            environment: env
        )
        guard result.exitCode == 0 else {
            throw AVDManagerError.subprocessFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return OutputParsing.parseSystemImages(result.stdout)
    }

    public func uninstall(package: String) async throws {
        guard let sdkmanager = await sdk.sdkmanagerPath else {
            throw AVDManagerError.missingSDK
        }
        let env = await sdk.environmentForSubprocess()
        let result = try await ProcessRunner.run(
            sdkmanager,
            arguments: ["--uninstall", package],
            environment: env
        )
        guard result.exitCode == 0 else {
            throw AVDManagerError.subprocessFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }

    public func download(package: String) async throws -> AsyncStream<DownloadProgress> {
        guard let sdkmanager = await sdk.sdkmanagerPath else {
            throw AVDManagerError.missingSDK
        }
        let env = await sdk.environmentForSubprocess()

        return AsyncStream { continuation in
            let task = Task {
                do {
                    let exitCode = try await ProcessRunner.runStreamingWithCancellation(
                        sdkmanager,
                        arguments: ["--install", package],
                        environment: env
                    ) { line in
                        if let progress = OutputParsing.parseDownloadProgress(from: line, package: package) {
                            continuation.yield(progress)
                        }
                    }

                    if exitCode == 0 {
                        continuation.yield(DownloadProgress(
                            package: package,
                            percent: 1.0,
                            bytesDownloaded: 1,
                            totalBytes: 1,
                            isComplete: true,
                            errorMessage: nil
                        ))
                    } else {
                        continuation.yield(DownloadProgress(
                            package: package,
                            percent: 0,
                            bytesDownloaded: 0,
                            totalBytes: 0,
                            isComplete: false,
                            errorMessage: "sdkmanager exited with code \(exitCode)"
                        ))
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(DownloadProgress(
                        package: package,
                        percent: 0,
                        bytesDownloaded: 0,
                        totalBytes: 0,
                        isComplete: false,
                        errorMessage: error.localizedDescription
                    ))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
