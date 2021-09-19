enum PokemonListRepositoryProvider {
    static func provide() -> PokemonListRepositoryContract {
        PokemonListRepository(apiDataStore: ApiDataStoreProvider.provide())
    }
}

protocol PokemonListRepositoryContract {
    func fetch() async throws -> PokemonListApiResponse
}

struct PokemonListRepository {
    private let apiDataStore: ApiDataStoreContract

    init(apiDataStore: ApiDataStoreContract) {
        self.apiDataStore = apiDataStore
    }
}

extension PokemonListRepository: PokemonListRepositoryContract {
    func fetch() async throws -> PokemonListApiResponse {
        try await apiDataStore.call(PokemonListApiRequest())
    }
}
