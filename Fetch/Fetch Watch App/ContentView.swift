import SwiftUI

struct Failure {
    var code: Int = 200
    var failed: Bool = false
}

struct Submission: Decodable {
    let difficulty: String
    let count: Int
}

struct ResponseData: Decodable {
    struct MatchedUser: Decodable {
        struct SubmitStats: Decodable {
            let acSubmissionNum: [Submission]
        }
        let submitStats: SubmitStats
    }
    let matchedUser: MatchedUser
}

struct GraphQLResponse: Decodable {
    let data: ResponseData
}

struct ContentView: View {
    @State private var interruption: Failure = Failure()
    @State private var count: [Submission] = []
    @State private var fetched: Bool = false
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Initial state
            if !fetched && !isLoading {
                Image(systemName: "link")
                    .imageScale(.large)
                    .foregroundStyle(Color("Color"))
                Text("Make API Calls")
                    .padding(.bottom)
                Button("Fetch!") {
                    Task {
                        isLoading = true
                        await fetchData()
                    }
                }
            }

            // Loading state
            if isLoading {
                ProgressView("fetching...")
            }

            // Result state
            if fetched && !isLoading {
                if interruption.failed {
                    Text("Failed To Fetch!")
                        .foregroundColor(.orange)
                    Text("[CODE: \(interruption.code)]")
                        .foregroundColor(.orange)
                        .font(.footnote)
                        .padding(.bottom)
                    Button {
                        Task {
                            isLoading = true
                            fetched = false
                            await fetchData()
                        }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .imageScale(.large)
                            .foregroundStyle(Color("Color"))
                    }
                } else {
                    ForEach(count, id: \.difficulty) { item in
                        Text("\(item.difficulty): \(item.count)")
                            .foregroundStyle(matchColor(for: item.difficulty))
                    }
                }
            }
        }
        .padding()
    }

    func matchColor(for difficulty: String) -> Color {
        switch difficulty {
        case "Easy": return .green
        case "Medium": return .yellow
        case "Hard": return .red
        default: return .gray
        }
    }

    @MainActor
    func fetchData() async {
        let url = URL(string: "https://leetcode.com/graphql")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let query = """
        {
            matchedUser(username: "AmirMahdi-Tizchang") {
                submitStats: submitStatsGlobal {
                    acSubmissionNum {
                        difficulty
                        count
                        submissions
                    }
                }
            }
        }
        """

        let body = ["query": query]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                interruption = Failure(code: httpResponse.statusCode, failed: true)
            } else {
                let decoded = try JSONDecoder().decode(GraphQLResponse.self, from: data)
                count = decoded.data.matchedUser.submitStats.acSubmissionNum
                interruption = Failure() // Reset error state
            }
        } catch {
            interruption = Failure(code: 499, failed: true)
        }

        isLoading = false
        fetched = true
    }
}

#Preview {
    ContentView()
}
