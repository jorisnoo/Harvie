# TODO

Open items from the October 2026 app review.

## QR bill compliance

- **Scissors symbol / "Separate before paying in".** The Swiss Payment Standards require either a scissors symbol on the separation lines or the text "Separate before paying in" above the payment part when the bill is sent as a PDF. The lines are drawn in `QRBillRenderer` but carry neither.
- **"Acceptance point" on the receipt.** The receipt is missing the mandatory "Acceptance point" heading in its bottom-right corner (`QRBillRenderer`, receipt section).

## To verify

- **`launchservicesd` mach-lookup exception** in `Harvie/Harvie.entitlements` (App Store build). No code obviously needs it; it may have been added for `NSSharingService(named: .composeEmail)` under the sandbox. Test "Send via Email" in a sandboxed build without it and drop it if email still works. App Review rejects temporary exceptions it can't see a reason for.
- **Swiss cross artwork.** `QRBillRenderer` draws the cross at 7 × 7 mm using Swiss flag proportions. Compare it against the official SIX graphic.
- **Total hours on templates.** Harvest line items don't say whether they came from time entries, so every line except the "Product" category counts as hours. A renamed product category would be counted.
- **Template printing.** Templates are printed with WebKit's print operation, and a sliced screen render is the fallback when printing fails. Check page breaks and page margins with a long invoice in the real app.

## Deliberately not changed

- **Creditor reference collisions.** `CreditorReferenceGenerator` strips non-alphanumerics and truncates, so "2024-001" and "2024/001" share a reference. Switching to the invoice ID would change the reference on every invoice already sent, which breaks reconciliation for outstanding payments. Revisit only together with a migration plan.
- **Data-protection keychain.** Keychain items are now written with `kSecAttrAccessibleWhenUnlocked`, but still live in the file-based keychain. `kSecUseDataProtectionKeychain` needs an application-identifier entitlement, which Developer ID builds without a provisioning profile don't have.
