//
//  SyncService.swift
//  Graphnote
//
//  Created by Hayden Pennington on 4/4/23.
//

import Foundation

enum SyncServiceError: Error {
    case fetchFailed
    case decoderFailed
    case userNotFound
    case unknown
}

class SyncService: ObservableObject {
    static let shared = SyncService()
    @Published private(set) var statusCode: Int = 200
    @Published private(set) var error: SyncServiceError? = nil
    
    private(set) var watching = false
    private var timer: Timer? = nil
    private var requestIDs: Set<UUID> = Set()
    
    private lazy var queue: SyncQueue? = nil
    
    func startQueue(user: User) {
        if queue == nil {
            self.queue = SyncQueue(user: user)
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            self.processQueue()
        }

        watching = true
    }
    
    func stopQueue() {
        self.timer?.invalidate()
        self.timer = nil
        watching = false
    }
    
    private func processQueue() {
        if let queueItem = self.queue?.peek() {
            if !requestIDs.contains(queueItem.id) {
                requestIDs.insert(queueItem.id)
                request(message: queueItem) { response in
                    if let response {
                        switch response.statusCode {
                        case 201, 409:
                            // Drop the item from the queue
                            self.queue?.remove(id: queueItem.id)
                            break
                        default:
                            print("generic request method in processQueue returned statusCode: \(response.statusCode)")
                        }
                        
                        self.statusCode = response.statusCode
                    }

                    self.requestIDs.remove(queueItem.id)
                    
                }
            }
        }
    }
    
    let baseURL = URL(string: "http://10.0.0.207:3000/")!
    
    enum HTTPMethod: String {
        case post
        case get
    }
    
    func request(message: SyncMessage, callback: @escaping (_ response: HTTPURLResponse?) -> Void) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var request = URLRequest(url: baseURL.appendingPathComponent("message"))
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(message)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                print(error)
                callback(nil)
            }
            
            if let response = response as? HTTPURLResponse {
                callback(response)
            }
            
            if let data {
                print(data)
            }
        }
        
        task.resume()
    }
    
    func createUser(user: User) {
        // Create message
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let contents = try! encoder.encode(user)
        let jsonString = String(data: contents, encoding: .utf8)!
        let message = SyncMessage(id: UUID(), user: user.id, timestamp: .now, type: .user, action: .create, isSynced: false, contents: jsonString)
        
        // Save message to local queue
        print(self.queue?.add(message: message))
        
    }
    
    func createDocument(user: User, document: Document, workspace: Workspace) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let contents = try! encoder.encode(document)
        let jsonString = String(data: contents, encoding: .utf8)!
        let message = SyncMessage(id: UUID(), user: user.id, timestamp: .now, type: .document, action: .create, isSynced: false, contents: jsonString)
        
        // Save message to local queue
        print(self.queue?.add(message: message))
        
        let workspaceRepo = WorkspaceRepo(user: user)
        try? workspaceRepo.create(document: document, in: workspace, for: user)
        
    }
    
    func fetchUser(id: String, callback: @escaping (_ user: User?, _ error: SyncServiceError?) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent("user")
            .appending(queryItems: [.init(name: "id", value: id)]))
        request.httpMethod = "GET"
        print("SyncService fetchUser fetching: \(id)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                print(error)
                callback(nil, SyncServiceError.fetchFailed)
                return
            }
            
            if let response = response as? HTTPURLResponse {
                print(response.statusCode)
                print(response)
                switch response.statusCode {
                case 200:
                    if let data {
                        let decoder = JSONDecoder()

                        let formatter = DateFormatter()
                        formatter.calendar = Calendar(identifier: .iso8601)
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)

                        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
                            let container = try decoder.singleValueContainer()
                            let dateStr = try container.decode(String.self)

                            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
                            guard let date = formatter.date(from: dateStr) else {
                                print("Date parsing FAILED!")
                                return .now
                            }
                            
                            return date
        
                        })
                        
                        do {
                            let user = try decoder.decode(User.self, from: data)
                            callback(user, nil)
                        } catch let error {
                            print(error)
                            callback(nil, SyncServiceError.decoderFailed)
                        }
                        
                    }
                case 404:
                    callback(nil, SyncServiceError.userNotFound)
                default:
                    print("Response failed with statusCode: \(response.statusCode)")
                    callback(nil, SyncServiceError.unknown)
                }
                
            }
        }
        
        task.resume()
    }
}
