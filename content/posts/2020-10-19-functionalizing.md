+++
title = "Functional-izing Swift Code"
date = "2020-10-21 07:26:00+00:00"

[taxonomies]
tags = [ "combine", "ios", "programming", "swift",]

[extra]
comment = true
+++

_(Note: This post uses Swift 5.3 and the iOS 14 SDK)_

In [a recent post](/blog/combine-networking), we looked at using Combine to refactor networking code. Before that, I looked at [refactoring bloated networking functions](/blog/refactoring-functions). Today I'd like to take another stab at refactoring. This time, however, we'll be using a style that _looks_ a lot like Combine, but uses a more "traditional" functional style without using Combine at all. <!-- more -->

Like previously, we'll be starting with the following basic network code.

```swift
enum NetworkError: Error {
    case decodeError(DecodingError)
    case encodeError(EncodingError)
    case badResponse(URLResponse?)
    case noData
    case other(Error)
    case unknown
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

As the comments indicate, over half of that completion block is just handling various cases that we're interpreting as an error. Why don't we factor that all out? It makes sense to me to factor it out into a function that takes in the `Data?`, `Response?`, and `Error?` and returns a `Result<Data, NetworkError>`. We'll also pull out an extra convenience error initializer, which will mostly come in handy later.

```swift
extension NetworkError {
    init(_ error: Error) {
        switch error {
        case let ne as NetworkError: self = ne
        case let de as DecodingError: self = .decodeError(de)
        case let ee as EncodingError: self = .encodeError(ee)
        default: self = .other(error)
        }
    }
}

extension Result where Success == Data, Failure == NetworkError {
    static func networkResult(
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) -> Self {
        if let e = error { return .failure(.init(e)) }

        guard let hr = response as? HTTPURLResponse,
              (200...299).contains(hr.statusCode)
        else { return .failure(.badResponse(response)) }

        guard let d = data else { return .failure(.noData) }

        return .success(d)
    }
}
```

(Using a `static func` rather than an initializer makes it easier for us to perform early exits, and also signals that this isn't quite a "usual" initializer; it has a specific domain usage.)

Now we can tear a lot of the error-checking code out of the `fetch` method. We can also make use of `Result.flatMap`, which allows us to transform a success value (if present) into a new `Result` with a new `Success`. With a regular `map`, this would produce a nested `Result<Result<NewSuccess, Failure>, Failure>`, but `flatMap` flattens this into a single-leveled `Result`.

Now our closure looks a lot simpler and, in my opinion, more readable.

```swift
URLSession.shared.dataTask(with: request) { d, r, e in
    let dataResult = Result.networkResult(data: d, response: r, error: e)
    let itemResult = dataResult.flatMap { data -> Result<T, NetworkError> in
        do {
            let item = try JSONDecoder().decode(T.self, from: data)
            return .success(item)
        } catch {
            return .failure(NetworkError(error))
        }
    }
    completion(itemResult)
}.resume()
```

We could even take this further and write a `tryMap` method on `Result` (this is present on a lot of Combine publishers).

```swift
extension Result {
    func tryMap<NewSuccess>(
        _ transform: (Success) throws -> NewSuccess
    ) -> Result<NewSuccess, Error> {
        Result<NewSuccess, Error> {
			try transform(try self.get())
		}
    }
}

class Networker {
    func fetch<T: Decodable>(
        _ type: T.Type,
        with request: URLRequest,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        URLSession.shared.dataTask(with: request) { d, r, e in
            let result = Result.networkResult(data: d, response: r, error: e)
                .tryMap { try JSONDecoder().decode(T.self, from: $0) }
                .mapError(NetworkError.init)
            completion(result)
        }.resume()
    }
}
```

Because we can't have "typed" `throw`s in Swift ([yet][typed throws]), we have to map our error after the `tryMap`, but otherwise, this is quite nice and functional!

...And we could take it even further if we wanted, making it all declarative and in-line.

```swift
URLSession.shared.dataTask(with: request) { d, r, e in
    completion(
        Result.networkResult(data: d, response: r, error: e)
            .tryMap { try JSONDecoder().decode(T.self, from: $0) }
            .mapError(NetworkError.init)
    )
}.resume()
```

I don't really like this, though; it's getting too close to being an overly-nested "pyramid of doom." There is a way we can fix it, but it can be a bit divisive...

We can write a custom operator!

```swift
/// "Pipe" an item into a function. Can help reduce nesting and improve clarity.
func |> <T, U>(
    _ item: T,
    _ transform: (T) -> U
) -> U {
    transform(item)
}
```

From what I understand, this operator is present in some functional languages, and although it may seem weird at first, in practice it makes a ton of sense and reads very nicely.

```swift
URLSession.shared.dataTask(with: request) { d, r, e in
    Result.networkResult(data: d, response: r, error: e)
        .tryMap { try JSONDecoder().decode(T.self, from: $0) }
        .mapError(NetworkError.init)
        |> completion
}.resume()
```

Looking at this, the "order of operations" is very clear; we take this network result, try mapping it, map any error, and pipe that into the completion closure.

We could go further by writing some "functional types" to essentially wrap various kinds of methods, but I'll leave that to the fellows at [PointFree](http://pointfree.co)!
