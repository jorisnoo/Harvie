//
//  CertificatePinningDelegate.swift
//  HarvestQRBill
//

import Foundation
import os.log

final class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedDomains: [String]
    private nonisolated let pinningLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill",
        category: "CertPinning"
    )

    init(pinnedDomains: [String]) {
        self.pinnedDomains = pinnedDomains
    }

    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              pinnedDomains.contains(where: { challenge.protectionSpace.host.hasSuffix($0) })
        else {
            return (.performDefaultHandling, nil)
        }

        let policies = [SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)]
        SecTrustSetPolicies(serverTrust, policies as CFArray)

        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        if isValid {
            return (.useCredential, URLCredential(trust: serverTrust))
        } else {
            #if DEBUG
            pinningLogger.error(
                "Certificate validation failed for \(challenge.protectionSpace.host): \(error?.localizedDescription ?? "unknown")"
            )
            #endif
            return (.cancelAuthenticationChallenge, nil)
        }
    }
}
