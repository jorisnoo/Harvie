# Changelog

All notable changes to this project will be documented in this file.

## [0.2.5](https://github.com/jorisnoo/HarvestQRBill/releases/tag/v0.2.5) (2026-02-11)

### Features

- add feedback tab to settings with contact and issue reporting links ([bb368ce](https://github.com/jorisnoo/HarvestQRBill/commit/bb368cec86498b3cf94debe135aec330473e9a0a))
- add markdown filter to template engine for rich text in descriptions and notes ([f121b73](https://github.com/jorisnoo/HarvestQRBill/commit/f121b73f0947587264131bb527f9543cc957f1a2))
- add feature flags ([4044a32](https://github.com/jorisnoo/HarvestQRBill/commit/4044a327fc99619535b7e3c9fe406b53a3d7a3ca))
- add column visibility toggles and total hours to invoice templates ([2fcf4df](https://github.com/jorisnoo/HarvestQRBill/commit/2fcf4df40c7e331be14bbe06a3c989ef6c5e487d))
- add custom templates ([fc4841c](https://github.com/jorisnoo/HarvestQRBill/commit/fc4841c8d9baf2b331aa0e09ae0524a68cde38fb))

### Bug Fixes

- skip QR bill generation for unsupported currencies ([28fb2e3](https://github.com/jorisnoo/HarvestQRBill/commit/28fb2e3e56dcbaf10fafd0efdebbc5afeffe52d1))
- set A4 dimensions and 75% zoom for template PDF rendering ([dfd0288](https://github.com/jorisnoo/HarvestQRBill/commit/dfd02886a6e6b7a5438eccc93559c3681f4b4855))
- harden WKWebView configuration for template PDF rendering with non-persistent data store, disabled JS, and proper window-server GPU context ([0e2c61e](https://github.com/jorisnoo/HarvestQRBill/commit/0e2c61e4f144f1224108b379ab6dcf837f6d561f))
- add hidden render window for WKWebView GPU context and terminate app on last window close ([cf18273](https://github.com/jorisnoo/HarvestQRBill/commit/cf182733127316265c00163aba844e7366f11da9))
- add column toggle CSS defaults to templates and ensure visibility overrides cascade correctly ([1b214e7](https://github.com/jorisnoo/HarvestQRBill/commit/1b214e7c52d6f06d7408bfda8b64907f0aa7e7ca))
- set description column width to 100% in all invoice templates for proper table layout ([91dadd2](https://github.com/jorisnoo/HarvestQRBill/commit/91dadd2b2818c02f5a92f40582eefe57406e5998))
- improve TemplatePreviewView stability with navigation delegate, crash recovery, and launch services entitlement ([0578c6e](https://github.com/jorisnoo/HarvestQRBill/commit/0578c6e4cce1b891ac4618dd1d390590d8178369))
- use single Window for main scene and scope classic template column alignment to items table ([394fa44](https://github.com/jorisnoo/HarvestQRBill/commit/394fa44be3d55f035292c4c510afcd18ddd5ec2b))
- add timeout and robust error handling to template PDF rendering ([99c49cb](https://github.com/jorisnoo/HarvestQRBill/commit/99c49cb747ff26e5ed284692694d7736fd0fb84f))

### Code Refactoring

- replace manual save button with debounced auto-save for settings ([14817b4](https://github.com/jorisnoo/HarvestQRBill/commit/14817b41d999436550eb9be258dfc18ee3e3c4c7))
- extract CSS custom properties and fix editor window lifecycle management ([7b0f3c7](https://github.com/jorisnoo/HarvestQRBill/commit/7b0f3c73b6de2311f9e2174f037c3a01acea99a1))
- extract shared utilities, deduplicate API/PDF logic, and add reusable ConfirmationSheet ([d8486f8](https://github.com/jorisnoo/HarvestQRBill/commit/d8486f8a4f492888542f3c0b5afb6c29f8f91571))

### Chores

- disable customPDFTemplates feature flag and mark templates tab as beta ([208d2e1](https://github.com/jorisnoo/HarvestQRBill/commit/208d2e1bb5eb6cb89cf4facd11ac2cb650c49461))
## [0.2.4](https://github.com/jorisnoo/HarvestQRBill/releases/tag/v0.2.4) (2026-02-11)

### Features

- reload invoices and creditor info when settings are saved, add retry button to setup prompt ([3e9d676](https://github.com/jorisnoo/HarvestQRBill/commit/3e9d6768f58cc4858ffede08d3b4c9110b18fb91))
- show setup required prompt with open settings button when credentials are missing ([705afd9](https://github.com/jorisnoo/HarvestQRBill/commit/705afd9035e3b2981ace4d363c270aaa62fc24c0))
## [0.2.3](https://github.com/jorisnoo/HarvestQRBill/releases/tag/v0.2.3) (2026-02-11)

### Code Refactoring

- use focusedSceneValue instead of NotificationCenter for menu refresh action ([14560f7](https://github.com/jorisnoo/HarvestQRBill/commit/14560f78490227292587908fcfe343ed31c91413))
- use native Settings scene and NotificationCenter instead of focused values for settings and refresh ([88f2a6f](https://github.com/jorisnoo/HarvestQRBill/commit/88f2a6fe458a17f6327da7d4e6bca036ecec6024))
## [0.2.2](https://github.com/jorisnoo/HarvestQRBill/releases/tag/v0.2.2) (2026-02-11)

### Features

- wrap demo mode code in #if DEBUG to exclude it from release builds ([ea6d2e6](https://github.com/jorisnoo/HarvestQRBill/commit/ea6d2e649fdc1edc63fbc95a556ac1206a74d73a))
- add auto-update install flow with restart prompt and disable app sandbox for direct distribution ([b8df5b7](https://github.com/jorisnoo/HarvestQRBill/commit/b8df5b7e6ab3ebf2693ecf26fa9692e1f58cffae))
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
