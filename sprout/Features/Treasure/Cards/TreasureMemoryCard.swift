import SwiftUI
import UIKit

struct TreasureMemoryCard: View {
    let item: TreasureTimelineItem

    var body: some View {
        VStack(spacing: 0) {
            if !loadedImages.isEmpty {
                MemoryMediaView(images: loadedImages)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(metaText)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(TreasureTheme.textSecondary)

                if let milestoneTitle = item.milestoneTitle {
                    Text(milestoneTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TreasureTheme.textPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let note = item.note?.trimmed.nilIfEmpty {
                    Text(note)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TreasureTheme.textPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if item.hasImageLoadError {
                    Text(L10n.text("treasure.memory.image_error", en: "This photo couldn't load just now.", zh: "这张照片暂时没有加载出来。"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(TreasureTheme.textSecondary.opacity(0.7))
                }
            }
            .padding(.horizontal, TreasureTheme.contentPadding)
            .padding(.vertical, TreasureTheme.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            ZStack {
                TreasureTheme.paperWhite
                if item.isMilestone || item.isGrowthMilestone {
                    TreasureTheme.terracottaGlow
                }
            }
        }
        .clipShape(TopRoundedCardShape(radius: TreasureTheme.cardRadius))
    }

    private var loadedImages: [LoadedTreasureImage] {
        item.imageLocalPaths.enumerated().compactMap { index, path in
            guard let image = UIImage(contentsOfFile: path) else { return nil }
            return LoadedTreasureImage(id: index, image: image)
        }
    }

    private var metaText: String {
        let formatter = TreasureTimestampFormatter.shared
        let timestamp = formatter.string(from: item.createdAt, ageInDays: item.ageInDays)
        return (item.isMilestone || item.isGrowthMilestone) ? "★ \(timestamp)" : timestamp
    }
}

private struct LoadedTreasureImage: Identifiable {
    let id: Int
    let image: UIImage
}

private struct MemoryMediaView: View {
    let images: [LoadedTreasureImage]

    var body: some View {
        if images.count == 1, let image = images.first {
            SingleMemoryImageView(image: image.image)
        } else {
            MemoryCarouselView(images: images)
        }
    }
}

private struct SingleMemoryImageView: View {
    let image: UIImage

    var body: some View {
        Color.clear
            .aspectRatio(TreasureTheme.mediaAspectRatio, contentMode: .fit)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}

private struct MemoryCarouselView: View {
    let images: [LoadedTreasureImage]

    @State private var selection = 0

    var body: some View {
        Color.clear
            .aspectRatio(TreasureTheme.mediaAspectRatio, contentMode: .fit)
            .overlay {
                ZStack(alignment: .bottom) {
                    TabView(selection: $selection) {
                        ForEach(images) { image in
                            Image(uiImage: image.image)
                                .resizable()
                                .scaledToFill()
                                .tag(image.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.14),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 36)
                    .allowsHitTesting(false)
                }
            }
            .clipped()
            .rootPagerGestureExclusion()
    }
}

enum TreasureTimestampFormatter {
    static let shared = Formatter()

    final class Formatter {
        private let formatter: DateFormatter
        private let localizationService: LocalizationService
        private let localeFormatter: LocaleFormatter

        init() {
            localizationService = .current
            localeFormatter = LocaleFormatter(localizationService: localizationService)
            formatter = DateFormatter()
            formatter.locale = localizationService.locale
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        }

        func string(from date: Date, ageInDays: Int?) -> String {
            let dateText = formatter.string(from: date)
            if let ageInDays {
                return L10n.format(
                    "treasure.memory.meta.with_age",
                    service: localizationService,
                    locale: localizationService.locale,
                    en: "%@ · %@ days",
                    zh: "%@ · %@天",
                    arguments: [dateText, localeFormatter.integer(ageInDays)]
                )
            }
            return dateText
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
