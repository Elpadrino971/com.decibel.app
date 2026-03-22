import Foundation

nonisolated enum ExportFormat: String, CaseIterable, Sendable, Identifiable {
    case pdf
    case csv

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pdf: "PDF"
        case .csv: "CSV"
        }
    }

    var icon: String {
        switch self {
        case .pdf: "doc.richtext"
        case .csv: "tablecells"
        }
    }

    var fileExtension: String {
        rawValue
    }

    var mimeType: String {
        switch self {
        case .pdf: "application/pdf"
        case .csv: "text/csv"
        }
    }
}
