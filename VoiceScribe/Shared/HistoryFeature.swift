import ComposableArchitecture
import Foundation
import Perception

struct HistoryFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var copiedRecordID: UUID?
        var historyLimit: Int

        init(historyLimit: Int = 25) {
            self.historyLimit = historyLimit
        }
    }

    enum Action: Equatable {
        case appeared
        case copyTapped(UUID, String)
        case clearCopied(UUID)
    }

    var clipboardClient: ClipboardClient = PasteboardClipboardClient()
    var copyFeedbackDuration: Duration = .seconds(2)

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .appeared:
                return .none

            case .copyTapped(let id, let text):
                clipboardClient.copy(text)
                state.copiedRecordID = id

                guard copyFeedbackDuration > .zero else {
                    return .none
                }

                return .run { send in
                    try? await Task.sleep(for: copyFeedbackDuration)
                    await send(.clearCopied(id))
                }
                .cancellable(id: "history.copyFeedback", cancelInFlight: true)

            case .clearCopied(let id):
                guard state.copiedRecordID == id else {
                    return .none
                }
                state.copiedRecordID = nil
                return .none
            }
        }
    }
}
