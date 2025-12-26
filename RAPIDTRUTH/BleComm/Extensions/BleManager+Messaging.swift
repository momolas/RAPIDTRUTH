//
//  BleManager+Messaging.swift
//  SmartOBD2
//
//  Created by Jules the Agent on Refactor.
//

import Foundation
import CoreBluetooth
import OSLog

extension BLEManager {

    // MARK: - Message Sending

    // Using Swift Concurrency (Actor) for queue management would be ideal,
    // but here we keep the existing logic structure but cleaned up.

    func waitForTurn() async {
        await withCheckedContinuation { continuation in
            queueLock.lock()
            if !isProcessing {
                isProcessing = true
                queueLock.unlock()
                continuation.resume()
            } else {
                commandQueue.append(continuation)
                queueLock.unlock()
            }
        }
    }

    func signalNext() {
        queueLock.lock()
        if !commandQueue.isEmpty {
            let next = commandQueue.removeFirst()
            queueLock.unlock()
            next.resume()
        } else {
            isProcessing = false
            queueLock.unlock()
        }
    }

    func sendMessageAsync(_ message: String) async throws -> [String] {
        // Wait for turn in the queue
        await waitForTurn()
        defer { signalNext() }

        let messageToSend = "\(message)\r"

        if debug {
            logger.info("Sending: \(messageToSend)")
        }

        guard let connectedPeripheral = self.connectedPeripheral,
              let ecuCharacteristic = self.ecuCharacteristic,
              let data = messageToSend.data(using: .ascii) else {
            logger.error("Error: Missing peripheral or characteristic.")
            throw SendMessageError.missingPeripheralOrCharacteristic
        }

        connectedPeripheral.peripheral.writeValue(data, for: ecuCharacteristic, type: .withResponse)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            var didResume = false
            let resumeLock = NSLock()

            let handler = { (response: [String]?, error: Error?) in
                resumeLock.lock()
                defer { resumeLock.unlock() }

                if didResume { return }
                didResume = true

                if let response {
                    continuation.resume(returning: response)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: SendMessageError.timeout)
                }
            }

            // Set up a timeout task
            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }

                guard let self = self else { return }
                self.logger.warning("Timeout waiting for response")
                handler(nil, SendMessageError.timeout)

                await MainActor.run {
                    self.sendMessageCompletion = nil
                }
            }

            self.sendMessageCompletion = { [weak self] response, error in
                timeoutTask.cancel()
                handler(response, error)

                // Clear the completion handler to release references
                Task { @MainActor [weak self] in
                    self?.sendMessageCompletion = nil
                }
            }
        }
    }
}
