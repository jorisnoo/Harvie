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
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              pinnedDomains.contains(where: { challenge.protectionSpace.host.hasSuffix($0) })
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let policies = [SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)]
        SecTrustSetPolicies(serverTrust, policies as CFArray)

        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        if isValid {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            #if DEBUG
            pinningLogger.error("Certificate validation failed for \(challenge.protectionSpace.host): \(error?.localizedDescription ?? "unknown")")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
