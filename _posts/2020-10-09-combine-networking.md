---
title: Functional-izing Network Code with Swift Combine
date: 2020-10-09 12:29
categories:
  - Code
---

_(Note: This post uses Swift 5.3 and the iOS 14 SDK)_

As I mentioned in my [previous post][previous post], using the Combine framework might require somewhat of a paradigm shift. In some ways, the best way to accomplish this might be to jump all in feet first and use it for all your networking and reactive code. However, this may not be entirely necessary, as Apple has also made it easy to gradually transition your codebase over to using Combine. <!--more-->

## Wrapping at the Call Site

Let's say we have the following vastly-oversimplified networking code. (We'll ignore that we have to use the shared `URLSession` to fetch data, a default `JSONDecoder` to decode it, etc.)

```swift
enum NetworkError: Error {
    case decodeError(DecodingError)
    case encodeError(EncodingError)
    case badResponse(Int)
    case noResponse
    case noData
    case other(Error)
    case unknown

    init(_ error: Error?) {
        // transform error into NetworkError
    }
}

class Networker {
    func fetch<T: Decodable>(
        with request: URLRequest,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            // catch any errors
            if let e = error { return completion(.failure(.other(e))) }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else { return completion(.failure(.badResponse(response))) }
            guard let d = data else { return completion(.failure(.noData)) }

            // decode and return
            do {
                let item = try JSONDecoder().decode(T.self, from: d)
                completion(.success(item))
            } catch {
                return completion(.failure(.decodeError(error)))
            }
        }.resume()
    }
}
```

We could replace all of this with Combine, but let's say for the moment that for whatever reason we're not allowed to change or even extend this class; we can only change some of the code that calls it. Let's say one of those places is the following (again ignoring any lack of flexibility for now, and imagining that there could be many more functions, properties, and request configuration):

```swift
struct User: Codable {
    let id: UUID
    let screenName: String
}

struct Habit: Codable {
    let id: UUID
    let name: String
}

class HabitStore {
    let baseURL = URL(string: "http://myendpoint.net")!
    let user: User

    init(user: User) {
        self.user = user
    }

    func fetchRemoteHabits(completion: @escaping (Result<[Habit], NetworkError>) -> Void) {
        let url = baseURL
            .appendingPathComponent("habits")
            .appendingPathComponent(user.id.uuidString)
        let request = URLRequest(url: url)
        Networker().fetch([Habit].self, with: request, completion: completion)
    }
}
```

If we wanted to, we could replace and refactor this method and anything that calls it. But we could also just write an extension on the class and an "overload" method (meaning a method with the same name but different parameters) that returns a publisher. There also just so happens to be a publisher that will work quite well with what we already have without many changes.

Let's look at (part of) the definition of the `Future` class.

```swift
class Future<Output, Failure: Error>: Publisher {
    typealias Promise = (Result<Output, Failure>) -> Void

    init(_ attemptToFulfill: @escaping (@escaping Future<Output, Failure>.Promise) -> Void)
}
```

That initializer looks quite terrifying; it takes in a closure, which in turn takes in its own closure (typealiased as `Promise`). Without the typealias, it looks like this:

```swift
((Result<Output, Failure>) -> Void) -> Void
```

Yikes! But look at that inner closure; looks familiar doesn't it? It's the same kind of closure we've been using for our networking completion handler! That makes adapting our existing code very easy.

```swift
extension HabitStore {
    func fetchRemoteHabits() -> Future<[Habit], NetworkError> {
        Future { [weak self] promise in
            self?.fetchRemoteHabits(completion: promise)
        }
    }
}
```

(Note that because the closure `Future` takes in is `@escaping`, we need to explicitly use `self`, which is a good signal to us that we need to use `[weak self]` so we don't run into any retain cycles.)

That was easy! Now we can take our time transitioning over to using this implementation of the fetch method. If we wanted to future-proof it, we could even add a `.eraseToAnyPublisher` so we're not restricted to using the `Future` publisher, but this shouldn't make much of a difference at the callsite.

## Replacing the Base Network Code

Let's say that down the line, we've stopped using the old fetch method entirely, and the rest of our team has given us the okay to replace the old networking method with a publisher. Once again, Apple has made things pretty easy for us; `URLSession` has a `dataTaskPublisher` whose `Output` is a tuple containing both `Data` and a `URLResponse`, with any `Error` as the `Failure` type. Now we can really leverage Combine to write our fetch method.

```swift
extension Result where Success == Data, Failure == NetworkError {
    init(data: Data?, response: URLResponse?) {
        // check data and response, etc
    }
}

extension Networker {
    func fetch<T: Decodable>(
        _ type: T.Type,
        with request: URLRequest
    ) -> AnyPublisher<T, NetworkError> {
        URLSession.shared.dataTaskPublisher(for: request)                // 1
            .tryMap { (d, r) in try Result(data: d, response: r).get() } // 2
            .decode(type: T.self, decoder: JSONDecoder())                // 3
            .mapError(NetworkError.init)                                 // 4
            .eraseToAnyPublisher()                                       // 5
    }
}
```

Let's walk through each of those lines:

1. Initialize the data task publisher using the provided `URLRequest`.
2. Most of the work here is being delegated to a custom `Result` initializer whose main purpose is to check that our data and response are both valid, otherwise throw an error. We could instead create a custom `validate` method if we wanted to.
3. Decode our custom type from the JSON data. This could throw a `DecodingError` if it's unsuccessful.
4. If we got an error at any point, we map over that and wrap it in our `NetworkError` from earlier.
5. We erase the specific, complicated type of the publisher by wrapping it in an `AnyPublisher` to vastly simplify our method's return type.

If we wanted to be lazy, we could have just done what we did at first with our call site code and wrap our old code in a `Future`...

```swift
extension Networker {
    func fetch<T: Decodable>(
        _ type: T.Type,
        with request: URLRequest
    ) -> AnyPublisher<T, NetworkError> {
        Future { [weak self] promise in
            self?.fetch(T.self, with: request, completion: promise)
        }.eraseToAnyPublisher()
    }
}
```

...but where's the fun in that?! (Of course this is a very reasonable option, especially if you still have legacy code to support.)

Either way, the callsite will now look almost exactly the same as before. I've reformatted it here to be all inline & declarative.

```swift
extension HabitStore {
    func fetchRemoteHabits() -> AnyPublisher<[Habit], NetworkError> {
        Networker().fetch(
            [Habit].self,
            with: URLRequest(
                url: baseURL
                    .appendingPathComponent("habits")
                    .appendingPathComponent(user.id.uuidString)
            )
        )
    }
}
```

So if things are generally the same in the end, was there any purpose to all of this?! Well, it basically depends on your preferences and how your networking code will be used. Here's a basic fake view class with a couple of methods; one uses the old fetch that takes in a closure, and the other uses the new fetch that returns a publisher.

```swift
class HabitListView {
    let store: HabitStore
    var habits: [Habit] = []

    var cancellables = Set<AnyCancellable>()

    init(store: HabitStore) {
        self.store = store
    }

    func onButtonTap_withCompletionClosure() {
        store.fetchRemoteHabits { [weak self] result in
            switch result {
            case .failure(let e):
                self?.displayAlert(for: e)
            case .success(let habits):
                self?.habits = habits
            }
        }
    }

    func onButtonTap_withPublisher() {
        store.fetchRemoteHabits()
            .sink { [weak self] in
                if case .failure(let e) = $0 { self?.displayAlert(for: e) }
            } receiveValue: { [weak self] in
                self?.habits = $0
            }.store(in: &cancellables)
    }

    func displayAlert(for error: Error) {
        // do something
    }
}
```

In this case, the Combine version adds the need to hang on to the subscription. Really you could also pass along the `dataTask` that is returned using the old URLSession method, so you would also have something you could cancel, but we don't _need_ to hang on to the data task like we do with the subscription.

The ability to easily map, merge, and perform other operations on publishers is one potential upside of using Combine. For example, we may want to merge with another publisher that fetches persisted objects from on device, or from another server.

```swift
func fetchFromDevice() -> AnyPublisher<[Habit], Error> {
    Just([])
        .mapError { _ in NetworkError.unknown as Error }
        .eraseToAnyPublisher()
}

func onButtonTap_mergeWithDevicePersistence() {
    store.fetchRemoteHabits()
        .mapError { $0 as Error }
        .merge(with: fetchFromDevice())
}
```

Hopefully that gives an idea of how we might be able to start moving in a more functional/reactive direction. This is really only the tip of the iceberg, though!

[previous post]: /blog/combine-intro
[typed throws]: https://forums.swift.org/t/typed-throws/39660/181
