import SwiftUI

/// Your prizes, shown on the outer display while the device is closed.
struct ShelfView: View {
    let shelf: PrizeShelf

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ForEach(Rarity.allCases.reversed(), id: \.self) { rarity in
                    section(rarity)
                }
                Label("Unfold to play", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(ClayStyle.backdrop)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CLAWKIT")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundStyle(ClayStyle.panel)
            Text("Your Shelf")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
            Text("\(shelf.uniqueCount) of \(PrizeKind.allCases.count) collected · \(shelf.total) total")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func section(_ rarity: Rarity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(rarity.title.uppercased())
                .font(.caption.weight(.black))
                .tracking(2)
                .foregroundStyle(rarity.color)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 12)], spacing: 12) {
                ForEach(PrizeKind.allCases.filter { $0.rarity == rarity }) { kind in
                    PrizeTile(kind: kind, count: shelf.count(of: kind))
                }
            }
        }
    }
}

private struct PrizeTile: View {
    let kind: PrizeKind
    let count: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ClayBall(color: count > 0 ? kind.color : .gray.opacity(0.35), diameter: 58)
                Image(systemName: count > 0 ? kind.symbol : "questionmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("×\(count)")
                        .font(.caption2.weight(.black).monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(ClayStyle.console, in: .capsule)
                        .foregroundStyle(.white)
                        .offset(x: 6, y: -4)
                }
            }
            Text(count > 0 ? kind.name : "???")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ShelfView(shelf: PrizeShelf())
}
