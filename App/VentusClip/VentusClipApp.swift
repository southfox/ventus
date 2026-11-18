import SwiftUI
import Ventus

@main
struct VentusClipApp: App {
    @State private var invocationURL: URL?

    var body: some Scene {
        WindowGroup {
            VentusClipView(invocationURL: invocationURL)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    invocationURL = activity.webpageURL
                }
        }
    }
}

private struct VentusClipView: View {
    let invocationURL: URL?
    @StateObject private var viewModel = VentusClipForecastViewModel()

    private var spot: VentusClipSpot {
        VentusClipSpot(invocationURL: invocationURL) ?? .bariloche
    }

    private var invocation: VentusClipInvocation? {
        AppClipDemoSession(invocationURL: invocationURL).map(VentusClipInvocation.init)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView("Loading forecast…")
                case let .loaded(forecast):
                    ForecastSummaryView(forecast: forecast, spot: spot, invocation: invocation)
                case let .failed(message):
                    ContentUnavailableView(
                        "Forecast unavailable",
                        systemImage: "icloud.slash",
                        description: Text(message)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(spot.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.load(spot: spot) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh forecast")
                }
            }
        }
        .task(id: spot.id) {
            await viewModel.load(spot: spot)
        }
    }
}

private struct ForecastSummaryView: View {
    let forecast: SpotForecast
    let spot: VentusClipSpot
    let invocation: VentusClipInvocation?

    private var hour: String? { forecast.currentForecastHour }
    private var data: Forecast? { forecast.forecast }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let invocation {
                    DemoSessionView(invocation: invocation)
                }

                HStack(alignment: .center, spacing: 18) {
                    Image(systemName: forecast.weatherSymbolName(hour: hour))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 56))
                        .frame(width: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(temperature)
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                        Text("Now in \(spot.displayName)")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 0) {
                    metricRow(title: "Wind", value: windSpeed, icon: "wind")
                    Divider()
                    metricRow(title: "Gusts", value: windGusts, icon: "wind")
                    Divider()
                    metricRow(title: "Rain", value: precipitation, icon: "cloud.rain")
                }
                .padding(.horizontal)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("Forecast powered by Windguru. Open Ventus for the complete hourly and marine forecast.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }

    private func metricRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.tint)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 16)
    }

    private var temperature: String {
        let value = data?.temperatureReal(hh: hour) ?? data?.temperature(hh: hour)
        return value.map { "\($0.formatted(.number.precision(.fractionLength(0))))°" } ?? "—"
    }

    private var windSpeed: String {
        guard let knots = data?.windSpeed(hh: hour) else { return "—" }
        return "\((knots * 1.852).formatted(.number.precision(.fractionLength(0)))) km/h"
    }

    private var windGusts: String {
        guard let value = data?.windGusts(hh: hour) else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0)))) km/h"
    }

    private var precipitation: String {
        guard let value = data?.precipitation(hh: hour) else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) mm"
    }
}

private struct DemoSessionView: View {
    let invocation: VentusClipInvocation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Demo session ready")
                    .font(.headline)
                Text("Flow: \(invocation.flowType)")
                    .font(.subheadline)
                Text(invocation.displayToken)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Demo session ready for \(invocation.flowType)")
    }
}

@MainActor
private final class VentusClipForecastViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(SpotForecast)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    private let forecastService = ForecastWindguruService()

    func load(spot: VentusClipSpot) async {
        state = .loading

        do {
            guard let forecast = try await forecastService.bestForecast(bySpotId: spot.id),
                  !forecast.availableForecastHours.isEmpty else {
                state = .failed("No forecast data is available for \(spot.displayName) right now.")
                return
            }
            state = .loaded(forecast)
        } catch {
            state = .failed("Check your connection and try again.")
        }
    }
}

private struct VentusClipSpot: Hashable {
    let id: String
    let slug: String
    let displayName: String

    private init(id: String, slug: String, displayName: String) {
        self.id = id
        self.slug = slug
        self.displayName = displayName
    }

    static let bariloche = Self(
        id: "64141",
        slug: "bariloche-dina-huapi",
        displayName: "Bariloche (Dina Huapi)"
    )

    init?(invocationURL: URL?) {
        guard let invocationURL else { return nil }
        let path = invocationURL.pathComponents.filter { $0 != "/" }
        guard path.dropFirst().last == Self.bariloche.slug else { return nil }
        self = .bariloche
    }
}

private struct VentusClipInvocation {
    let session: AppClipDemoSession

    init(_ session: AppClipDemoSession) {
        self.session = session
    }

    var bindingKey: String { session.bindingKey }
    var flowType: String { session.flowType }
    var displayToken: String { session.displayToken }
}
