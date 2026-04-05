import Foundation
import Observation

@MainActor
@Observable
final class ActiveBabyState {
    var headerConfig: HomeHeaderConfig

    init(headerConfig: HomeHeaderConfig = .placeholder) {
        self.headerConfig = headerConfig
    }

    func updateFrom(_ baby: BabyProfile?) {
        headerConfig = HomeHeaderConfig.from(baby)
    }
}
