# Changelog

All notable changes to this project will be documented in this file.

## [0.2.1](https://github.com/jorisnoo/HarvestQRBill/releases/tag/v0.2.1) (2026-02-11)

### Features

- replace full list reload with targeted invoice refresh and move GitHub repo config to Info.plist ([909cfa1](https://github.com/jorisnoo/HarvestQRBill/commit/909cfa1a16cedd45b40864e6e79830ebbfc05888))
- add search filtering for invoices by number and client name ([581018a](https://github.com/jorisnoo/HarvestQRBill/commit/581018aaa81c7b2c37bef884982938e21aeb4da2))
- refresh invoice list after updating issue date, marking as sent, or marking as draft ([3be5f19](https://github.com/jorisnoo/HarvestQRBill/commit/3be5f19c047ba64e1cd5b319686b1bfe500ce5e3))

### Code Refactoring

- add in-memory cache to KeychainService and use update-or-add instead of delete-then-add ([eefd204](https://github.com/jorisnoo/HarvestQRBill/commit/eefd204986e51628a2448f7498cf4e9bba9a3677))
## [0.2.0](https://github.com/jorisnoo/HarvestQRBill/releases/tag/v0.2.0) (2026-02-11)

### Features

- invoice detail view improved ([bd6ca13](https://github.com/jorisnoo/HarvestQRBill/commit/bd6ca1323b58008d666dfd5d6263d525e26b634d))
- ui cleanup ([e933b90](https://github.com/jorisnoo/HarvestQRBill/commit/e933b902c7373f607f233e7f0eb25d555e26b642))
- allow chaning invoice date and mark as sent/draft. ([279c668](https://github.com/jorisnoo/HarvestQRBill/commit/279c668cb4caffa3c44d9a33d6d64d584a12154e))
- add plausible ([c3f5b9b](https://github.com/jorisnoo/HarvestQRBill/commit/c3f5b9bb0b53c9478af9521fd703e82d5f8bcacc))
- add multi-selection detail view with export actions ([36bbb06](https://github.com/jorisnoo/HarvestQRBill/commit/36bbb0646ff5ef570aa3df47a5b5bceb10b0737e))
- add selection mode with native multi-select support ([faca70f](https://github.com/jorisnoo/HarvestQRBill/commit/faca70f163903a3678c008d1eafe3ef926ad08fa))
- adjust qr layout ([4f56043](https://github.com/jorisnoo/HarvestQRBill/commit/4f56043ca7d743bc15bdbb19a19c7198ad937361))
- add autoupdater ([e98132e](https://github.com/jorisnoo/HarvestQRBill/commit/e98132ec4b702a73e2c9adbfdf1f2744153bbed9))

### Bug Fixes

- list select ([d99397c](https://github.com/jorisnoo/HarvestQRBill/commit/d99397ce030597d3e9ef83a4d5bcb5188e56cefc))
- plausible ([dfaf253](https://github.com/jorisnoo/HarvestQRBill/commit/dfaf253736127a9c4dcb42a8a53a33f6b23c6781))
- api race condition ([92d800d](https://github.com/jorisnoo/HarvestQRBill/commit/92d800d7d59564bdc84716f7676e46d5a5c49ab8))
- cmd a to select ([f3728de](https://github.com/jorisnoo/HarvestQRBill/commit/f3728de665c6d808a8fa94fca79f3fc58da63ce1))
- implement security audit recommendations ([af0d4fe](https://github.com/jorisnoo/HarvestQRBill/commit/af0d4fe990d679d7bf3069d6cd62313fc7fbd476))
- quartely filter ([180449f](https://github.com/jorisnoo/HarvestQRBill/commit/180449f52a71d75c09971cbf8a2a0280884c5261))
- readme ([ef986df](https://github.com/jorisnoo/HarvestQRBill/commit/ef986dfe14531f65a0660df2938dd127f5ef88b7))

### Code Refactoring

- generalise build scripts, use British spelling for notarise, add App Store build config and notes heading ([6841814](https://github.com/jorisnoo/HarvestQRBill/commit/6841814e0b25ff12e96935be9ff1a919ea0bc69c))
- migrate analytics from AviaryInsights/Plausible to Aptabase with more granular event tracking ([3b3c073](https://github.com/jorisnoo/HarvestQRBill/commit/3b3c073e8b6645b819c75584a870d213867df2d3))
- simplify state indicator in detail view and clear invalid selections on filter/sort changes ([f7cbca9](https://github.com/jorisnoo/HarvestQRBill/commit/f7cbca9e7889a984681711b7c586de90462861a1))
- cleanup ([faeacc0](https://github.com/jorisnoo/HarvestQRBill/commit/faeacc08e6cd7b20625ddc03371d3343c79f1879))
- conform to swift 6 where possible ([8939446](https://github.com/jorisnoo/HarvestQRBill/commit/89394464eca1813932e0bf61b178777111eb8d1a))
- cleanup ([401dcaf](https://github.com/jorisnoo/HarvestQRBill/commit/401dcafe1028b7da799b8a95cd5d421a1dd395bf))

### Documentation

- update readme ([f509b74](https://github.com/jorisnoo/HarvestQRBill/commit/f509b74a5a48a0754e23caa56ea5cf04cf655702))
- add images to readme ([ab92c5c](https://github.com/jorisnoo/HarvestQRBill/commit/ab92c5c15ec03cbba3f7c5fb49187cea414bb167))

### Build System

- add app store toggle ([1fb43dd](https://github.com/jorisnoo/HarvestQRBill/commit/1fb43ddd4cc0ccc1093706a6ac158a3752b5e527))
- add ci script ([1bf0339](https://github.com/jorisnoo/HarvestQRBill/commit/1bf03399391bc1611ff6a1fbfc3441009867a0e4))
- add macosicon ([13a0b9c](https://github.com/jorisnoo/HarvestQRBill/commit/13a0b9ce521199fe46cff1f9e066c91a3b7a9f95))
- link to changelog in release file ([323de60](https://github.com/jorisnoo/HarvestQRBill/commit/323de60a6cfb93d2c1d8b6d22cb2fec1bcf335a0))
- remove unused packages ([d751b0b](https://github.com/jorisnoo/HarvestQRBill/commit/d751b0be90b61cd40647fa9435197cc0b44657fd))
- local build script ([e3f9571](https://github.com/jorisnoo/HarvestQRBill/commit/e3f9571ccdeb9c7db462c175e35ab16357f8b138))

### Chores

- replace AviaryInsights with Aptabase analytics SDK ([d886244](https://github.com/jorisnoo/HarvestQRBill/commit/d886244a23a32f850320dd2c2e38f4a73a999397))
- switch AppUpdater to jorisnoo fork v3.0.0 and remove PromiseKit dependency ([422c2ae](https://github.com/jorisnoo/HarvestQRBill/commit/422c2aeb0e7c1bee369bf60ee2d05d32608c1c9e))
- remove files from xcode ([4d63b67](https://github.com/jorisnoo/HarvestQRBill/commit/4d63b67ae603300c65d6aafb8d20dab9325ef127))
- sync version 0.1.3 to Xcode ([fa58577](https://github.com/jorisnoo/HarvestQRBill/commit/fa585774233abe08ca5fc971abc60cd0871805c9))
## [0.1.3](https://github.com/jorisnoo/HarvestQRBill/releases/tag/v0.1.3) (2026-01-20)

### Bug Fixes

- use git-auto-commit-action for version sync ([9d93ca9](https://github.com/jorisnoo/HarvestQRBill/commit/9d93ca9c9e318df0d98b608e774e36bed9a1123c))
## [0.1.2](https://github.com/jorisnoo/HarvestQRBill/releases/tag/v0.1.2) (2026-01-20)

### Documentation

- add readme ([0b1e70a](https://github.com/jorisnoo/HarvestQRBill/commit/0b1e70aedd13a38df3d4e67b5f606ff261cd8ce4))
## [0.1.0](https://github.com/jorisnoo/HarvestQRBill/releases/tag/0.1.0) (2026-01-20)

### Features

- Connect to Harvest account to fetch invoices
- Generate Swiss QR Bills compliant with Swiss Payment Standards
- Automatic SCOR reference generation (Creditor Reference ISO 11649)
- Export invoices with QR payment slip as PDF
- Secure credential storage in macOS Keychain
- Native macOS app built with SwiftUI
