//  Unit tests for the deterministic parsing logic (AGENTS.md rule 9).
//  Add a "Unit Testing Bundle" target named BillFixerTests in Xcode (Testing framework) — this folder is picked up automatically.
//  They also run without Xcode:  ./run-parser-checks.sh
#if canImport(Testing)
import Testing
#endif
#if canImport(BillFixer)
@testable import BillFixer
#endif
import Foundation

enum ParserFixtures {
    static let bill = OCRResult(rows: [
        "Riverside Medical Center", "123 Main St, Springfield", "STATEMENT",
        "Statement Date: 03/20/2024", "Account Number: RMC-448812", "Date of Service: 03/15/2024",
        "Primary Insurance: Blue Cross Blue Shield",
        "03/15/2024  99284  Emergency Dept Visit  1  $850.00",
        "03/15/2024  71046  Chest X-Ray 2 Views  1  $420.00",
        "03/15/2024  93000  EKG Complete  1  $210.00",
        "03/15/2024  71046  Chest X-Ray 2 Views  1  $420.00",
        "Total Charges  $1,900.00", "Insurance Payment  (665.44)", "Adjustments  $0.00",
        "Balance Due  $1,234.56",
    ].map { OCRRow(text: $0, confidence: 0.95, page: 0) }, pageCount: 1, usedTextLayer: false)

    static let eob = OCRResult(rows: [
        "Aetna Health", "EXPLANATION OF BENEFITS", "Claim Number: A1234567", "Provider: Riverside Medical Center",
        "In-network provider", "Amount Billed $1,900.00", "Allowed Amount $1,120.00", "Plan Paid $665.44",
        "Deductible $300.00", "Coinsurance $154.56", "What You Owe $454.56",
    ].map { OCRRow(text: $0, confidence: 0.9, page: 0) }, pageCount: 1, usedTextLayer: false)
}

func checkMoneyParsing() {
    precondition(Money(parsing: "$1,234.56")?.apiString == "1234.56")
    precondition(Money(parsing: "(12.00)")?.isNegative == true)
    precondition(Money(parsing: "12.00 CR")?.isNegative == true)
    precondition(Money(parsing: "abc") == nil)
    precondition(Money(parsing: "1.234") == nil)
}

func checkBillParser() {
    let d = BillParser.parse(ParserFixtures.bill)
    precondition(d.providerName == "Riverside Medical Center", "provider: \(d.providerName)")
    precondition(d.accountNumber == "RMC-448812", "account: \(d.accountNumber)")
    precondition(d.totalCharges == "1900.00", "total: \(d.totalCharges)")
    precondition(d.insurancePayment == "665.44", "ins: \(d.insurancePayment)")
    precondition(d.currentBalance == "1234.56", "balance: \(d.currentBalance)")
    precondition(d.insurerName.hasPrefix("Blue Cross"), "insurer: \(d.insurerName)")
    precondition(d.lineItems.count == 4, "lines: \(d.lineItems.map(\.description))")
    precondition(d.lineItems[1].code == "71046" && d.lineItems[1].total == "420.00")
    precondition(d.lineItems[0].description == "Emergency Dept Visit", "desc: \(d.lineItems[0].description)")
    precondition(d.serviceDateStart != nil && d.billDate != nil)
    precondition(d.validationError == nil, "validation: \(d.validationError ?? "")")
    let sub = d.submission(documentId: nil)
    precondition(sub.isItemized && sub.lineItems.count == 4 && sub.serviceDateEnd != nil)
}

func checkEOBParser() {
    let e = EOBParser.parse(ParserFixtures.eob)
    precondition(e.insurerName.hasPrefix("Aetna"), "insurer: \(e.insurerName)")
    precondition(e.claimNumber == "A1234567", "claim: \(e.claimNumber)")
    precondition(e.networkStatus == .inNetwork)
    precondition(e.billedAmount == "1900.00" && e.allowedAmount == "1120.00" && e.insurerPayment == "665.44")
    precondition(e.patientResponsibility == "454.56", "owe: \(e.patientResponsibility)")
    precondition(e.deductibleApplied == "300.00" && e.coinsurance == "154.56")
}

func checkDates() {
    precondition(TextPatterns.dates(in: "DOS 03/15/24 to Mar 17, 2024").count == 2)
    precondition(TextPatterns.dates(in: "02/30/2024").isEmpty)   // invalid day rejected
    precondition(DateHelpers.parseDay("2024-03-15").map(DateHelpers.dayString) != nil)
}

#if canImport(Testing)
@Suite struct ParserTests {
    @Test func money() { checkMoneyParsing() }
    @Test func bill() { checkBillParser() }
    @Test func eob() { checkEOBParser() }
    @Test func dates() { checkDates() }
}
#endif
