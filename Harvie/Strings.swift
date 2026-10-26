//
//  Strings.swift
//  Harvie
//

import Foundation

enum Strings {

    // MARK: - Common

    enum Common {
        static let ok = String(localized: "OK")
        static let cancel = String(localized: "Cancel")
        static let save = String(localized: "Save")
        static let delete = String(localized: "Delete")
        static let apply = String(localized: "Apply")
        static let retry = String(localized: "Retry")
        static let done = String(localized: "Done")
        static let today = String(localized: "Today")
        static let preview = String(localized: "Preview")
        static let edit = String(localized: "Edit")
        static let error = String(localized: "Error")
        static let success = String(localized: "Success")
        static let select = String(localized: "Select")
        static let settings = String(localized: "Settings")
        static let refresh = String(localized: "Refresh")
        static let find = String(localized: "Find")
        static let more = String(localized: "More")
    }

    // MARK: - App

    enum App {
        static let title = "Harvie"
        static let checkForUpdates = String(localized: "Check for Updates...")
        static let restartAndUpdate = String(localized: "Restart and Update")
    }

    // MARK: - Invoices List

    enum InvoicesList {
        static let title = String(localized: "Invoices")
        static let updating = String(localized: "Updating...")
        static let loading = String(localized: "Loading invoices...")
        static let noInvoices = String(localized: "No Invoices")
        static let setupRequired = String(localized: "Setup Required")
        static let openSettings = String(localized: "Open Settings")
        static let filterPrompt = String(localized: "Filter invoices")
        static let exportWithQRBill = String(localized: "Export with QR Bill")
        static let exportWithoutQRBill = String(localized: "Export without QR Bill")
        static let sortAndFilter = String(localized: "Sort & Filter")
        static let sortBy = String(localized: "Sort By")
        static let filterPeriod = String(localized: "Filter Period")
        static let all = String(localized: "All")
        static let stateOpen = String(localized: "Open")
        static let statePaid = String(localized: "Paid")
        static let stateDraft = String(localized: "Draft")
        static let stateClosed = String(localized: "Closed")
        static let stateFilterHint = String(localized: "Click to filter by state. Shift-click or \u{2318}-click to select several.")
        static let exportingInvoices = String(localized: "Exporting Invoices")
        static let creditorWarning = String(localized: "Configure creditor info in Settings to enable QR bill export.")

        // Sort options
        static let sortIssueDate = String(localized: "Issue Date")
        static let sortDueDate = String(localized: "Due Date")
        static let sortPaidDate = String(localized: "Paid Date")

        // Filter periods
        static let periodMonth = String(localized: "Month")
        static let periodQuarter = String(localized: "Quarter")
        static let periodHalfYear = String(localized: "Half Year")
        static let periodYear = String(localized: "Year")

        static func quarterPeriod(_ quarter: Int, _ year: Int) -> String {
            String(localized: "Q\(quarter) \(String(year))")
        }

        static func halfYearPeriod(_ half: Int, _ year: Int) -> String {
            String(localized: "H\(half) \(String(year))")
        }

        static func filterByPeriod(_ period: String) -> String {
            String(localized: "Filter by \(period)")
        }

        static func invoiceCount(_ count: Int) -> String {
            count == 1 ? String(localized: "1 invoice") : String(localized: "\(count) invoices")
        }

        static let noInvoicesDescription = String(localized: "No invoices found.")

        static func noInvoicesForState(_ state: String) -> String {
            String(localized: "No \(state) invoices found.")
        }
    }

    // MARK: - Invoice Detail

    enum InvoiceDetail {
        static let previewButton = String(localized: "Preview")
        static let exportQRBill = String(localized: "Export QR Bill")
        static let changeDate = String(localized: "Change Date")
        static let sendViaEmail = String(localized: "Send via Email\u{2026}")
        static let markAsSentNoEmail = String(localized: "Mark as Sent (no email)")
        static let send = String(localized: "Send")
        static let markAsSent = String(localized: "Mark as Sent")
        static let markAsDraft = String(localized: "Mark as Draft")
        static let markAsPaid = String(localized: "Mark as Paid")
        static let markAsOpen = String(localized: "Mark as Open")
        static let showInFinder = String(localized: "Show in Finder")
        static let invoiceTitle = String(localized: "Invoice title")
        static let saveTitle = String(localized: "Save title")
        static let notes = String(localized: "Notes")
        static let description = String(localized: "Description")
        static let price = String(localized: "Price")
        static let changeIssueDate = String(localized: "Change Issue Date")
        static let issueDate = String(localized: "Issue Date")
        static let updateIssueDateTitle = String(localized: "Update Issue Date?")
        static let setToToday = String(localized: "Set to Today")
        static let keepCurrentDate = String(localized: "Press Cancel to keep the current date.")

        static func updateIssueDateMessage(_ date: String) -> String {
            String(localized: "The issue date is set to \(date). Do you want to update it to today?")
        }
        static let invoiceSent = String(localized: "Invoice Sent")
        static let invoiceReverted = String(localized: "Invoice Reverted")
        static let invoiceMarkedPaid = String(localized: "Invoice Paid")
        static let invoiceReopened = String(localized: "Invoice Reopened")
        static let selectAnInvoice = String(localized: "Select an Invoice")
        static let selectAnInvoiceDescription = String(localized: "Choose an invoice from the list to view details and generate a QR bill.")

        static let previewTooltip = String(localized: "Preview invoice PDF with Swiss QR bill (Space)")
        static let exportTooltip = String(localized: "Download invoice PDF with Swiss QR bill")
        static let creditorRequiredTooltip = String(localized: "Configure creditor info in Settings first")
        static let sendTooltip = String(localized: "Send invoice via email or mark as sent")

        static func ofTotal(_ amount: String) -> String {
            String(localized: "of \(amount) total")
        }

        static func issuedAndSent(_ issueDate: String, _ sentTime: String) -> String {
            String(localized: "Issued \(issueDate), sent at \(sentTime)")
        }

        static func issued(_ date: String) -> String {
            String(localized: "Issued \(date)")
        }

        static func sent(_ date: String) -> String {
            String(localized: "Sent \(date)")
        }

        static func due(_ date: String) -> String {
            String(localized: "Due \(date)")
        }

        static let dueDate = String(localized: "Due Date")
        static let uponReceipt = String(localized: "Upon Receipt")

        static func customDays(_ days: Int) -> String {
            String(localized: "Custom (\(days) days)")
        }

        static func inclTax(_ rate: String, _ amount: String) -> String {
            String(localized: "Incl. \(rate)% tax (\(amount))")
        }

        static func discount(_ rate: String, _ amount: String) -> String {
            String(localized: "Discount \(rate)%: -\(amount)")
        }

        static func paid(_ date: String) -> String {
            String(localized: "Paid \(date)")
        }

        static func markAsSentMessage(_ number: String) -> String {
            String(localized: "Mark invoice \(number) as sent?")
        }

        static let sentDateDetail = String(localized: "The sent date will be set to now.")

        static func markAsDraftMessage(_ number: String) -> String {
            String(localized: "Revert invoice \(number) to draft?")
        }

        static func markAsPaidMessage(_ number: String) -> String {
            String(localized: "Mark invoice \(number) as paid?")
        }

        static let paymentDate = String(localized: "Payment Date")
        static let paidDateDetail = String(localized: "A payment for the full amount will be recorded.")

        static func markAsOpenMessage(_ number: String) -> String {
            String(localized: "Reopen invoice \(number)?")
        }

        static let reopenDetail = String(localized: "All payment records will be removed.")

        static func invoiceSentMessage(_ number: String) -> String {
            String(localized: "Invoice \(number) has been marked as sent.")
        }

        static func invoiceRevertedMessage(_ number: String) -> String {
            String(localized: "Invoice \(number) has been reverted to draft.")
        }

        static func invoiceMarkedPaidMessage(_ number: String) -> String {
            String(localized: "Invoice \(number) has been marked as paid.")
        }

        static func invoiceReopenedMessage(_ number: String) -> String {
            String(localized: "Invoice \(number) has been reopened.")
        }

        static func savedToPath(_ path: String) -> String {
            String(localized: "Invoice saved to:\n\(path)")
        }

        static let savedSuccessfully = String(localized: "Invoice with QR bill saved successfully.")

        static func failedAction(_ label: String, _ error: String) -> String {
            String(localized: "Failed to \(label): \(error)")
        }

        static func failedActionGeneric(_ label: String) -> String {
            String(localized: "Failed to \(label). Please try again.")
        }

        static func emailSubject(label: String, number: String, title: String?) -> String {
            if let title, !title.isEmpty {
                return "\(label) \(number) \(title)"
            }
            return "\(label) \(number)"
        }

        static let emailNotConfigured = String(localized: "Email is not configured on this Mac.")
    }

    // MARK: - New Invoice

    enum NewInvoice {
        static let title = String(localized: "New Invoice")
        static let newInvoiceMenu = String(localized: "New Invoice\u{2026}")
        static let create = String(localized: "Create Draft")
        static let loading = String(localized: "Loading clients\u{2026}")
        static let loadFailed = String(localized: "Couldn\u{2019}t Load Clients")
        static let client = String(localized: "Client")
        static let selectClient = String(localized: "Select a client\u{2026}")
        static let subject = String(localized: "Subject")
        static let subjectPlaceholder = String(localized: "Optional")
        static let paymentTerms = String(localized: "Payment Terms")
        static let lineItems = String(localized: "Line Items")
        static let kind = String(localized: "Kind")
        static let quantity = String(localized: "Qty")
        static let unitPrice = String(localized: "Unit Price")
        static let addLineItem = String(localized: "Add Line Item")
        static let removeLineItem = String(localized: "Remove line item")
        static let taxRate = String(localized: "Tax %")
        static let taxPlaceholder = String(localized: "None")
        static let subtotal = String(localized: "Subtotal")
        static let draftHint = String(localized: "The invoice is created as a draft. Harvest assigns the number.")
    }

    // MARK: - Delete Invoice

    enum DeleteInvoice {
        static let title = String(localized: "Delete Invoice")
        static let delete = String(localized: "Delete\u{2026}")
        static let detail = String(localized: "This permanently deletes the invoice and its payments from Harvest. This cannot be undone.")

        static func message(_ count: Int, number: String?) -> String {
            if count == 1, let number {
                return String(localized: "Delete invoice \(number)?")
            }
            return String(localized: "Delete \(count) invoices?")
        }
    }

    // MARK: - Estimates List

    enum EstimatesList {
        static let title = String(localized: "Estimates")
        static let updating = String(localized: "Updating...")
        static let loading = String(localized: "Loading estimates...")
        static let noEstimates = String(localized: "No Estimates")
        static let filterPrompt = String(localized: "Filter estimates")
        static let export = String(localized: "Export")
        static let markAsSent = String(localized: "Mark as Sent")
        static let markAsAccepted = String(localized: "Mark as Accepted")
        static let markAsDeclined = String(localized: "Mark as Declined")
        static let reopen = String(localized: "Reopen")
        static let stateDraft = String(localized: "Draft")
        static let stateSent = String(localized: "Sent")
        static let stateAccepted = String(localized: "Accepted")
        static let stateDeclined = String(localized: "Decl.")
        static let all = String(localized: "All")
        static let stateFilterHint = String(localized: "Click to filter by state. Shift-click or \u{2318}-click to select several.")
        static let exportingEstimates = String(localized: "Exporting Estimates")

        static func estimateCount(_ count: Int) -> String {
            count == 1 ? String(localized: "1 estimate") : String(localized: "\(count) estimates")
        }

        static func noEstimatesForState(_ state: String) -> String {
            String(localized: "No \(state) estimates found.")
        }

        static let noEstimatesDescription = String(localized: "No estimates found.")
    }

    // MARK: - Estimate Detail

    enum EstimateDetail {
        static let export = String(localized: "Export")
        static let selectAnEstimate = String(localized: "Select an Estimate")
        static let selectAnEstimateDescription = String(localized: "Choose an estimate from the list to view details and export.")
        static let notes = String(localized: "Notes")
        static let exportTooltip = String(localized: "Download estimate PDF")
        static let markAsSent = String(localized: "Mark as Sent")
        static let markAsAccepted = String(localized: "Mark as Accepted")
        static let markAsDeclined = String(localized: "Mark as Declined")
        static let reopen = String(localized: "Reopen")
        static let estimateSent = String(localized: "Estimate Sent")
        static let estimateAccepted = String(localized: "Estimate Accepted")
        static let estimateDeclined = String(localized: "Estimate Declined")
        static let estimateReopened = String(localized: "Estimate Reopened")

        static func estimateSentMessage(_ number: String) -> String {
            String(localized: "Estimate \(number) has been marked as sent.")
        }
        static func estimateAcceptedMessage(_ number: String) -> String {
            String(localized: "Estimate \(number) has been marked as accepted.")
        }
        static func estimateDeclinedMessage(_ number: String) -> String {
            String(localized: "Estimate \(number) has been marked as declined.")
        }
        static func estimateReopenedMessage(_ number: String) -> String {
            String(localized: "Estimate \(number) has been reopened.")
        }
        static func issued(_ date: String) -> String { String(localized: "Issued \(date)") }
        static func sent(_ date: String) -> String { String(localized: "Sent \(date)") }
        static func accepted(_ date: String) -> String { String(localized: "Accepted \(date)") }
        static func declined(_ date: String) -> String { String(localized: "Declined \(date)") }
    }

    // MARK: - Document Source

    enum DocumentSource {
        static let document = String(localized: "Document")
        static let invoices = String(localized: "Invoices")
        static let estimates = String(localized: "Estimates")
    }

    // MARK: - Multi Selection

    enum MultiSelection {
        static let total = String(localized: "Total")
        static let clients = String(localized: "Clients")
        static let bullet = "\u{2022}"

        static func invoicesSelected(_ count: Int) -> String {
            String(localized: "\(count) Invoices Selected")
        }

        static func setIssueDateMessage(_ count: Int) -> String {
            String(localized: "Set issue date for \(count) invoice(s)")
        }

        static func markAsSentMessage(_ count: Int) -> String {
            String(localized: "Mark \(count) invoice(s) as sent?")
        }

        static let sentDateDetail = String(localized: "The sent date will be set to the current time.")

        static func updateIssueDateMessage(_ count: Int) -> String {
            String(localized: "Some of the \(count) selected invoice(s) have an issue date that is not today. Do you want to update them to today?")
        }

        static func markAsDraftMessage(_ count: Int) -> String {
            String(localized: "Revert \(count) invoice(s) to draft?")
        }

        static func markAsPaidMessage(_ count: Int) -> String {
            String(localized: "Mark \(count) invoice(s) as paid?")
        }

        static func markAsOpenMessage(_ count: Int) -> String {
            String(localized: "Reopen \(count) invoice(s)?")
        }

        static func batchProgress(_ done: Int, _ total: Int) -> String {
            String(localized: "\(done) of \(total)")
        }
    }

    // MARK: - Settings

    enum Settings {
        static let harvest = String(localized: "Harvest")
        static let qrBill = String(localized: "QR Bill")
        static let downloads = String(localized: "Downloads")
        static let templates = String(localized: "Templates")
        static let feedback = String(localized: "Feedback")

        // Harvest
        static let apiCredentials = String(localized: "API Credentials")
        static let accessToken = String(localized: "Access Token")
        static let accountID = String(localized: "Account ID")
        static let testConnection = String(localized: "Test Connection")
        static let connected = String(localized: "Connected")
        static let failed = String(localized: "Failed")
        static let subdomain = String(localized: "Subdomain")
        static let apiCredentialsHint = String(localized: "Get your API credentials from Harvest Developer Tools.")
        static let getApiKey = String(localized: "Get an API key")
        static let saveFailedTitle = String(localized: "Couldn't Save Settings")

        // QR Bill
        static let creditorInformation = String(localized: "Creditor Information")
        static let iban = String(localized: "IBAN")
        static let name = String(localized: "Name")
        static let address = String(localized: "Address")
        static let street = String(localized: "Street")
        static let number = String(localized: "Number")
        static let zip = String(localized: "ZIP")
        static let city = String(localized: "City")
        static let country = String(localized: "Country")
        static let creditorHint = String(localized: "This information appears on the QR bill as the payment recipient.")

        // Downloads
        static let saveLocation = String(localized: "Save Location")
        static let saveBehavior = String(localized: "Save behavior")
        static let folder = String(localized: "Folder")
        static let notSet = String(localized: "Not set")
        static let chooseFolder = String(localized: "Choose...")
        static let filename = String(localized: "Filename")
        static let pattern = String(localized: "Pattern")
        static let dateFormat = String(localized: "Date format")
        static let availablePlaceholders = String(localized: "Available placeholders:")
        static let placeholderNumber = String(localized: "{number} - Invoice number")
        static let placeholderCreditor = String(localized: "{creditor} - Your company name")
        static let placeholderClient = String(localized: "{client} - Client name")
        static let placeholderDate = String(localized: "{date} - Date based on sort")
        static let placeholderIssueDate = String(localized: "{issueDate} - Issue date")
        static let placeholderDueDate = String(localized: "{dueDate} - Due date")
        static let placeholderPaidDate = String(localized: "{paidDate} - Paid date")
        static let dateFormatComponents = String(localized: "Date format components:")
        static let dateFormatHelp = String(localized: "YYYY (4-digit year), YY (2-digit year), MM (month), DD (day)")

        // Email Subject
        static let emailSubject = String(localized: "Email Subject")
        static let emailPlaceholderInvoice = String(localized: "{invoice} - Localized invoice label")
        static let emailPlaceholderNumber = String(localized: "{number} - Invoice number")
        static let emailPlaceholderTitle = String(localized: "{title} - Invoice title")
        static let emailPlaceholderClient = String(localized: "{client} - Client name")
        static let emailPlaceholderCreditor = String(localized: "{creditor} - Your company name")

        // Paid Mark
        static let paidMark = String(localized: "Paid Mark")
        static let showWatermark = String(localized: "Show watermark on paid invoices")
        static let showPaidDate = String(localized: "Show paid date")
        static let watermarkStyle = String(localized: "Watermark Style")
        static let watermarkHtmlHint = String(localized: "HTML: .watermark > .text + .date")
        static let resetToDefault = String(localized: "Reset to Default")

        // Company Logo
        static let companyLogo = String(localized: "Company Logo")
        static let noLogoSet = String(localized: "No logo set")
        static let chooseImage = String(localized: "Choose Image...")
        static let remove = String(localized: "Remove")
        static let logoHint = String(localized: "Used only in custom templates. Harvest PDFs use the logo configured in Harvest.")

        // Templates
        static let invoicePDFSource = String(localized: "Invoice PDF Source")
        static let pdfSource = String(localized: "PDF source")
        static let language = String(localized: "Language")
        static let customizeLabels = String(localized: "Customize labels")
        static let noCustomLabels = String(localized: "No labels customized yet.")
        static let showQuantityColumn = String(localized: "Show Quantity column")
        static let showUnitPriceColumn = String(localized: "Show Unit Price column")
        static let showTotalHours = String(localized: "Show Total Hours")
        static let templateColumnHint = String(localized: "To hide columns on Harvest PDFs, change this in the Harvest web UI.")
        // swiftlint:disable:next line_length
        static let harvestColumnHint = String(localized: "Column visibility can be configured when using a custom template. For Harvest PDFs, change this in the Harvest web UI under Invoices \u{2192} Configure \u{2192} Hide columns.")
        static let templatesFolder = String(localized: "Templates Folder")
        static let useDefaultFolder = String(localized: "Use Default")
        static let templatesFolderHint = String(localized: "Choose a folder in iCloud Drive or another synced location to share your templates between Macs.")
        static let selectTemplatesFolder = String(localized: "Choose a folder for your templates")
        static let moveTemplatesTitle = String(localized: "Move Your Templates?")
        // swiftlint:disable:next line_length
        static let moveTemplatesMessage = String(localized: "Your current templates can move to the new folder. Choose \u{201C}Don\u{2019}t Move\u{201D} if that folder already holds the templates you want, for example from another Mac. Templates you don\u{2019}t move stay in the old folder.")
        static let moveTemplates = String(localized: "Move Templates")
        static let dontMove = String(localized: "Don\u{2019}t Move")
        static let templatesFolderErrorTitle = String(localized: "Couldn\u{2019}t Change Templates Folder")

        // Feedback
        static let contact = String(localized: "Contact")
        static let contactEmail = "hello@harvie.app"
        static let contactHint = String(localized: "Send us an email with questions, suggestions, or feedback.")
        static let website = String(localized: "Website")
        static let websiteURL = "harvie.app"
        static let privacyPolicy = String(localized: "Privacy Policy")
        static let reportAnIssue = String(localized: "Report an Issue")
        static let openGitHubIssues = String(localized: "Open GitHub Issues")
        static let reportHint = String(localized: "Report bugs or request features on GitHub.")

        // Clients
        static let clients = String(localized: "Clients")
        static let clientOverrides = String(localized: "Client Overrides")
        static let addOverride = String(localized: "Add Override")
        static func overrideCount(_ count: Int) -> String {
            count == 1 ? String(localized: "1 client") : String(localized: "\(count) clients")
        }
        static func removeOverride(_ name: String) -> String {
            String(localized: "Remove Override for \(name)")
        }
        static let overrideLanguage = String(localized: "Override language")
        static let overrideColumnVisibility = String(localized: "Override column visibility")
        static let overrideLabels = String(localized: "Override labels")
        static let noOverridesHint = String(localized: """
            Add per-client overrides to use different settings for specific clients. \
            Unchecked fields use the global default.
            """)
        static let noClientsHint = String(localized: "Clients will appear here once invoices have been loaded.")
        static let selectClient = String(localized: "Select a client...")

        static func settingsFor(_ name: String) -> String {
            String(localized: "Settings for \(name)")
        }

        // Debug
        static let demo = String(localized: "Demo")
        static let demoMode = String(localized: "Demo Mode")
    }

    // MARK: - Templates

    enum Templates {
        static let templateName = String(localized: "Template Name")
        static let readOnly = String(localized: "Read Only")
        static let openInEditor = String(localized: "Open in Editor")
        static let variables = String(localized: "Variables")
        static let refreshPreview = String(localized: "Refresh preview")
        static let newTemplate = String(localized: "New template")
        static let duplicateTemplate = String(localized: "Duplicate template")
        static let deleteTemplate = String(localized: "Delete template")
        static let revealTemplatesFolder = String(localized: "Reveal templates folder")
        static let deleteTemplateTitle = String(localized: "Delete Template")
        static let duplicate = String(localized: "Duplicate")
        static let openInExternalEditor = String(localized: "Open in External Editor")
        static let revealInFinder = String(localized: "Reveal in Finder")
        static let untitledTemplate = String(localized: "Untitled Template")
        static let builtIn = String(localized: "Built-in")
        static let export = String(localized: "Export\u{2026}")
        static let exportTemplate = String(localized: "Export template")
        static let importTemplate = String(localized: "Import template")
        static let importMessage = String(localized: "Select a template file to import")
        static let importErrorTitle = String(localized: "Import Failed")
        static let editorMode = String(localized: "Editor")
        static let dontSave = String(localized: "Don\u{2019}t Save")
        static let unsavedChangesMessage = String(localized: "Your changes will be lost if you don\u{2019}t save them.")

        static func unsavedChangesTitle(_ name: String) -> String {
            String(localized: "Do you want to save the changes made to \"\(name)\"?")
        }

        static func deleteConfirmation(_ name: String) -> String {
            String(localized: "Are you sure you want to delete \"\(name)\"? This cannot be undone.")
        }

        static func builtInWindowTitle(_ name: String) -> String {
            String(localized: "\(name) (Built-in \u{2014} Read Only)")
        }

        static func previewWindowTitle(_ name: String) -> String {
            String(localized: "Preview \u{2014} \(name)")
        }

        static func updatedAt(_ date: String) -> String {
            String(localized: "Updated \(date)")
        }
    }

    // MARK: - Template Variables

    enum TemplateVariables {
        // Categories
        static let invoice = String(localized: "Invoice")
        static let client = String(localized: "Client")
        static let creditor = String(localized: "Creditor")
        static let lineItems = String(localized: "Line Items")
        static let conditionals = String(localized: "Conditionals")
        static let labels = String(localized: "Labels")
        static let filters = String(localized: "Filters")

        // Variables
        static let number = String(localized: "Number")
        static let totalAmount = String(localized: "Total Amount")
        static let currency = String(localized: "Currency")
        static let subject = String(localized: "Subject")
        static let notes = String(localized: "Notes")
        static let issueDate = String(localized: "Issue Date")
        static let dueDate = String(localized: "Due Date")
        static let subtotal = String(localized: "Subtotal")
        static let taxPercent = String(localized: "Tax %")
        static let taxAmount = String(localized: "Tax Amount")
        static let discountPercent = String(localized: "Discount %")
        static let discountAmount = String(localized: "Discount Amount")
        static let totalHours = String(localized: "Total Hours")
        static let name = String(localized: "Name")
        static let address = String(localized: "Address")
        static let iban = String(localized: "IBAN")
        static let street = String(localized: "Street")
        static let buildingNumber = String(localized: "Building No.")
        static let postalCode = String(localized: "Postal Code")
        static let town = String(localized: "Town")
        static let country = String(localized: "Country")
        static let loopStart = String(localized: "Loop Start")
        static let loopEnd = String(localized: "Loop End")
        static let description = String(localized: "Description")
        static let quantity = String(localized: "Quantity")
        static let unitPrice = String(localized: "Unit Price")
        static let amount = String(localized: "Amount")
        static let ifHasNotes = String(localized: "If Has Notes")
        static let endIf = String(localized: "End If")
        static let ifHasTax = String(localized: "If Has Tax")
        static let ifHasDiscount = String(localized: "If Has Discount")
        static let ifHasSubject = String(localized: "If Has Subject")
        static let rate = String(localized: "Rate")
        static let price = String(localized: "Price")
        static let vat = String(localized: "VAT")
        static let discount = String(localized: "Discount")
        static let total = String(localized: "Total")
        static let totalDue = String(localized: "Total Due")
        static let due = String(localized: "Due")
        static let date = String(localized: "Date")
        static let from = String(localized: "From")
        static let billTo = String(localized: "Bill To")
        static let details = String(localized: "Details")
        static let paymentDetails = String(localized: "Payment Details")
        static let reSubject = String(localized: "Re/Subject")
        static let dateFormat = String(localized: "Date Format")
        static let currencyFormat = String(localized: "Currency Format")
        static let trimmedNumberFormat = String(localized: "Trimmed Number Format")
    }

    // MARK: - Label Editor

    enum LabelEditor {
        static let title = String(localized: "Customize Labels")
        static let templateLabels = String(localized: "Template Labels")
        static let qrBillLabels = String(localized: "QR Bill Labels")
        static let resetLanguage = String(localized: "Reset Language")
        static let resetToDefault = String(localized: "Reset to default")
    }

    // MARK: - Alerts

    enum Alerts {
        static let exportError = String(localized: "Export Error")
        static let exportComplete = String(localized: "Export Complete")
        static let updateError = String(localized: "Update Error")
        static let updateComplete = String(localized: "Update Complete")
        static let celebrationDismissHint = String(localized: "Press Esc to dismiss celebration")

        static func exportedCount(_ count: Int) -> String {
            String(localized: "Successfully exported \(count) invoice(s).")
        }

        static func updatedCount(_ count: Int) -> String {
            String(localized: "Successfully updated \(count) invoice(s).")
        }

        static func exportedEstimateCount(_ count: Int) -> String {
            String(localized: "Successfully exported \(count) estimate(s).")
        }

        static func updatedEstimateCount(_ count: Int) -> String {
            String(localized: "Successfully updated \(count) estimate(s).")
        }
    }

    // MARK: - Errors

    enum Errors {
        // Credentials
        nonisolated static let configureCredentials = String(localized: "Please configure your Harvest API credentials in Settings.")
        nonisolated static let configureCreditor = String(localized: "Please configure your creditor information in Settings.")
        nonisolated static let noTemplateSelected = String(localized: "No template selected. Please select a template in Settings > Templates.")

        // Connection
        nonisolated static let fillCredentials = String(localized: "Please fill in Access Token and Account ID.")
        nonisolated static let connectionFailed = String(localized: "Connection failed.")
        nonisolated static let connectionFailedNetwork = String(localized: "Connection failed. Please check your network.")

        // API
        nonisolated static let invalidCredentials = String(localized: "Invalid API credentials. Please check your settings.")
        nonisolated static let invalidURL = String(localized: "Failed to construct API request.")
        nonisolated static let invalidSubdomain = String(localized: "Invalid Harvest subdomain.")
        nonisolated static let unauthorized = String(localized: "Unauthorized. Please check your API token.")
        nonisolated static let notFound = String(localized: "Resource not found.")
        nonisolated static let networkFailed = String(localized: "Network connection failed.")
        nonisolated static let decodingFailed = String(localized: "Failed to parse server response.")

        nonisolated static func serverError(_ code: Int) -> String {
            String(localized: "Server error (code: \(code))")
        }

        // PDF
        nonisolated static let downloadFailed = String(localized: "Failed to download the PDF from Harvest.")
        nonisolated static let invalidPDF = String(localized: "The downloaded file is not a valid PDF.")
        nonisolated static let saveFailed = String(localized: "Failed to save the PDF file.")
        nonisolated static let qrBillGenerationFailed = String(localized: "Failed to generate the QR bill.")
        nonisolated static let renderingFailed = String(localized: "Failed to render the template to PDF.")
        nonisolated static let processTerminated = String(localized: "The web rendering process terminated unexpectedly.")
        nonisolated static let renderingTimeout = String(localized: "PDF rendering timed out.")

        // QR Bill
        nonisolated static let invalidIBAN = String(localized: "Invalid IBAN format.")
        nonisolated static let qrIBANNotSupported = String(localized: "QR-IBAN is not supported. Please use a regular Swiss IBAN.")
        nonisolated static let invalidCreditorAddress = String(localized: "Creditor address is incomplete.")
        nonisolated static let invalidAmount = String(localized: "Amount must be between 0.01 and 999,999,999.99.")
        nonisolated static let invalidCurrency = String(localized: "Currency must be CHF or EUR.")
        nonisolated static let invalidReference = String(localized: "Invalid creditor reference format.")
        nonisolated static let messageTooLong = String(localized: "Combined message and billing info must not exceed 140 characters.")

        // Keychain
        nonisolated static let keychainEncodingFailed = String(localized: "Failed to prepare data for the keychain.")
        nonisolated static let keychainDecodingFailed = String(localized: "Failed to read data from the keychain.")
        nonisolated static let keychainNotFound = String(localized: "No saved data found in the keychain.")

        nonisolated static func keychainSaveFailed(_ detail: String) -> String {
            String(localized: "Failed to save to the keychain: \(detail)")
        }

        nonisolated static func keychainLoadFailed(_ detail: String) -> String {
            String(localized: "Failed to load from the keychain: \(detail)")
        }

        nonisolated static func keychainDeleteFailed(_ detail: String) -> String {
            String(localized: "Failed to delete from the keychain: \(detail)")
        }
    }

    // MARK: - Export

    enum Export {
        static let selectFolderMessage = String(localized: "Select folder to save invoices")
        static let selectFolderMessageEstimates = String(localized: "Select folder to save estimates")
        static let exportComplete = String(localized: "Export complete!")
        static let selectLogoMessage = String(localized: "Select a company logo image")
        static let choosePrompt = String(localized: "Choose")
        static let selectFolderForDownloads = String(localized: "Select default download folder for invoices")

        static func exportingProgress(_ index: Int, _ total: Int, _ number: String) -> String {
            String(localized: "Exporting \(index) of \(total): \(number)")
        }
    }

    // MARK: - Data Export Window

    enum DataExport {
        static let menuItem = String(localized: "Export All Data\u{2026}")
        static let windowTitle = String(localized: "Export Harvest Data")
        static let intro = String(localized: "Download all data from your Harvest account as JSON and CSV files.")
        static let outputFolder = String(localized: "Output Folder")
        static let chooseFolder = String(localized: "Choose\u{2026}")
        static let noFolderSelected = String(localized: "No folder selected")
        static let selectFolderPrompt = String(localized: "Select a folder to save the exported files")
        static let resourcesSection = String(localized: "Resources to Export")
        static let formatNote = String(localized: "Exports both JSON and CSV for each selected resource, plus a manifest.json with run details.")
        static let selectAll = String(localized: "Select All")
        static let selectNone = String(localized: "Select None")
        static let startExport = String(localized: "Start Export")
        static let cancel = String(localized: "Cancel")
        static let exportRunning = String(localized: "Exporting\u{2026}")
        static let revealInFinder = String(localized: "Reveal in Finder")
        static let needsCredentials = String(localized: "Connect your Harvest account in Settings before exporting.")

        static func progressMessage(_ resource: String, _ done: Int, _ total: Int) -> String {
            String(localized: "Exporting \(resource) (\(done) of \(total))\u{2026}")
        }

        static func successSummary(_ resourceCount: Int, _ rowCount: Int) -> String {
            let resources = resourceCount == 1
                ? String(localized: "1 resource")
                : String(localized: "\(resourceCount) resources")
            let records = rowCount == 1
                ? String(localized: "1 total record")
                : String(localized: "\(rowCount) total records")
            return String(localized: "Exported \(resources) (\(records)).")
        }

        static func failureSummary(_ message: String) -> String {
            String(localized: "Export failed: \(message)")
        }

        static func failedCount(_ count: Int) -> String {
            String(localized: "\(count) failed")
        }
    }

    // MARK: - Refresh Warning

    enum RefreshWarning {
        static let showingSavedData = String(localized: "Showing saved data. Balances and statuses may be out of date.")

        static func refreshFailed(_ error: String) -> String {
            String(localized: "Refresh failed: \(error)")
        }

        static func showingSavedDataFrom(_ date: String) -> String {
            String(localized: "Showing saved data from \(date).")
        }
    }
}
