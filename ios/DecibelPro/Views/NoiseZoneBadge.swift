import SwiftUI

struct NoiseZoneBadge: View {
    let zone: NoiseZone
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: zone.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(zone.color)
                .symbolEffect(.bounce, value: zone)

            VStack(alignment: .leading, spacing: 1) {
                Text(zone.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(zone.color)
                Text(zone.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(zone.range.lowerBound))–\(Int(zone.range.upperBound)) dB")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
        .opacity(isActive ? 1 : 0.4)
    }
}
