import Alamofire
import Foundation

enum ApiDataStoreProvider {
    static func provide() -> ApiDataStoreContract {
        ApiDataStore(
            reachabilityDataStore: ReachabilityDataStoreProvider.provide(),
            session: Alamofire.AF,
            decoder: .default
        )
    }
}

protocol ApiDataStoreContract {
    func call<Request: ApiRequestable>(_ request: Request) async throws -> Request.Response
    func cancel()
}

final class ApiDataStore {
    private let reachabilityDataStore: ReachabilityDataStore
    private let session: Alamofire.Session
    private let decoder: JSONDecoder
    private var dataRequest: Alamofire.DataRequest?

    init(
        reachabilityDataStore: ReachabilityDataStore,
        session: Alamofire.Session,
        decoder: JSONDecoder
    ) {
        self.reachabilityDataStore = reachabilityDataStore
        self.session = session
        self.decoder = decoder
    }

    private var isReachable: Bool {
        reachabilityDataStore.isReachable
    }
}

extension ApiDataStore: ApiDataStoreContract {
    func call<Request: ApiRequestable>(_ request: Request) async throws -> Request.Response {
        guard isReachable else {
            throw ApiError.connection
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.dataRequest = session.request(
                request.url,
                method: request.method,
                parameters: request.parameters,
                encoding: request.encoding,
                headers: request.headers
            ).validate(statusCode: 200..<300).responseData { [weak self] response in
                guard let self = self else {
                    return
                }

                if response.response?.statusCode == 204,
                   let noContents = NoContents() as? Request.Response {
                    continuation.resume(returning: noContents)
                }

                switch response.result {
                case let .success(data):
                    do {
                        let success = try self.decoder.decode(Request.Response.self, from: data)
                        continuation.resume(returning: success)
                    } catch {
                        continuation.resume(throwing: ApiError.decodingFailure)
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cancel() {
        dataRequest?.cancel()
    }
}
