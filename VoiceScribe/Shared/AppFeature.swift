import ComposableArchitecture
import Foundation
import Perception

struct AppFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var pipeline: PipelineFeature.State
        var settings: SettingsFeature.State
        var history: HistoryFeature.State

        init(
            pipeline: PipelineFeature.State = .init(),
            settings: SettingsFeature.State = .init()
        ) {
            self.pipeline = pipeline
            self.settings = settings
            self.history = HistoryFeature.State(historyLimit: settings.historyLimit)
        }
    }

    enum Action: Equatable {
        case pipeline(PipelineFeature.Action)
        case settings(SettingsFeature.Action)
        case history(HistoryFeature.Action)
    }

    var pipeline: PipelineFeature
    var settings: SettingsFeature
    var history: HistoryFeature

    init(
        pipeline: PipelineFeature = .init(),
        settings: SettingsFeature = .init(),
        history: HistoryFeature = .init()
    ) {
        self.pipeline = pipeline
        self.settings = settings
        self.history = history
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .pipeline(let action):
                return pipeline
                    .reduce(into: &state.pipeline, action: action)
                    .map(Action.pipeline)

            case .settings(let action):
                let effect = settings
                    .reduce(into: &state.settings, action: action)
                    .map(Action.settings)

                switch action {
                case .appeared, .historyLimitSelected:
                    state.history.historyLimit = state.settings.historyLimit
                default:
                    break
                }

                return effect

            case .history(let action):
                return history
                    .reduce(into: &state.history, action: action)
                    .map(Action.history)
            }
        }
    }
}
