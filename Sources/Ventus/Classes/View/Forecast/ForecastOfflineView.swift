//
//  ForecastOfflineView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 07/26/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS)
import SwiftUI

struct ForecastOfflineView: View {
    let retry: () -> Void
    let errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    init(retry: @escaping () -> Void, errorMessage: String? = nil) {
        self.retry = retry
        self.errorMessage = errorMessage
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.05, green: 0.08, blue: 0.13), Color(red: 0.19, green: 0.12, blue: 0.13)]
                    : [Color(red: 0.39, green: 0.68, blue: 0.82), Color(red: 0.96, green: 0.58, blue: 0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Circle()
                        .fill(.yellow.opacity(colorScheme == .dark ? 0.40 : 0.85))
                        .frame(width: 78, height: 78)
                        .offset(x: proxy.size.width * 0.26, y: -proxy.size.height * 0.40)

                    desertDune(color: Color(red: 0.75, green: 0.35, blue: 0.16), width: proxy.size.width * 1.6)
                        .offset(x: -proxy.size.width * 0.18, y: 66)
                    desertDune(color: Color(red: 0.93, green: 0.57, blue: 0.24), width: proxy.size.width * 1.7)
                        .offset(x: proxy.size.width * 0.14, y: 122)

                    Image(systemName: "wind")
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(.white.opacity(0.58))
                        .offset(x: isAnimating ? proxy.size.width * 0.22 : -proxy.size.width * 0.26, y: -proxy.size.height * 0.12)
                        .opacity(isAnimating ? 0.25 : 0.78)
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating, value: isAnimating)

                Text("Can’t reach Windguru")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Check your Wi-Fi or mobile data, then try again.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: 310)

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(4)
                        .frame(maxWidth: 310)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                }

                Button("Try Again", systemImage: "arrow.clockwise", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.92))
                    .foregroundStyle(Color.orange)
                    .padding(.top, 8)

            }
            .padding(28)
        }
        .task {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }

    private func desertDune(color: Color, width: CGFloat) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: width, height: 210)
    }
}

#Preview("Offline") {
    ForecastOfflineView(retry: {})
}
#endif
