+++
title = "Refactoring Bloated Functions"
date = "2020-06-04 09:21:00+00:00"

[taxonomies]
tags = [ "ios", "programming", "swift", "swiftui",]

[extra]
comment = true
+++

_(Note: This post uses Swift 5.2)_

I recently completed time as a Team Lead at Lambda School, where I was responsible for reviewing and offering feedback on students' code. One of the biggest benefits I took away from this experience was the value of writing readable code. To that end, I thought I would share some quick tips that, in my opinion, can help improve the organization and readability of your code.<!-- more -->

I'll be using Swift in this article, but the principles should apply to many modern programming languages.

Let's take the following code as a starting point.

```swift
struct Object: Codable {
   var title: String
   var date: Date
   var content: String
}

class APIController {
   let baseURL = URL(string: "https://example.com")!

   func fetchObject(
      withTitle title: String,
      dateInterval: DateInterval?,
      completion: @escaping (Result<Object, NetworkError>) -> Void
   ) {
      var urlComponents = URLComponents(
         url: baseURL,
         resolvingAgainstBaseURL: true)!
      urlComponents.queryItems = [URLQueryItem(name: "title", value: title)]

      if let dates = dateInterval {
         let dateFormatter = DateFormatter()
         dateFormatter.timeStyle = .none
         dateFormatter.dateStyle = .short
         let start = dateFormatter.string(from: dates.start)
         let end = dateFormatter.string(from: dates.end)
         urlComponents.queryItems?.append(contentsOf: [
            URLQueryItem(name: "startdate", value: start),
            URLQueryItem(name: "enddate", value: end)
         ])
      }

      guard let url = urlComponents.url else {
         completion(.failure(.badURL))
         return
      }
      let request = URLRequest(url: url)

      URLSession.shared.dataTask(with: request) { data, response, error in
         if let error = error {
            completion(.failure(.other(error)))
            return
         }

         // check response status code (2xx = good)
         if let httpResponse = response as? HTTPURLResponse,
            !(200...299).contains(httpResponse.statusCode)
         {
            completion(.failure(.badResponse(code: httpResponse.statusCode)))
            return
         }

         guard let data = data else {
            completion(.failure(.noData))
            return
         }

         do {
            let object = try JSONDecoder().decode(Object.self, from: data)
            completion(.success(object))
         } catch {
            completion(.failure(.decodeError(error)))
         }
      }.resume()
   }
}

enum NetworkError: Error {
   case badURL
   case noData
   case decodeError(Error)
   case badResponse(code: Int)
   case deallocatedAPIController
   case other(Error)
}
```

_(Note that I usually don't like to force-unwrap things, but in cases like this (a bad `baseURL`), a crash would be programmer error and we can easily write a unit test to protect ourselves.)_

We have an a basic model struct called `Object`, an `APIController` class that handles fetching an instance of the object from a URL, and an enum that declares the different kinds of errors we might run into along the way.

There's a _lot_ happening here, and we haven't even looked at any view code that would call this. If we've seen something like this before, it might not be too difficult to parse. However, we can still improve readability & organization and make things more testable & reusable should we decide to expand our app's functionality.

One of the guiding principles I like to use is to keep each method as clear, straightforward, succinct, and readable as possible, abstracting out any complexity into smaller helper methods, so that each method does basically only one primary thing with as few side effects as possible.

Sometimes it can help to plan out the steps taken. In `fetchObject`, we want to:

- Construct the `URLRequest` from the provided title string and optional `DateInterval`
  - If a dateInterval was passed in, transform it into `QueryItem`s that can be added to the URL
- Create (and start) a data task using this request
- When we get the data task response, parse it into our model, making sure it's what we expect

## Constructing the URL Request

With our plan in place, let's start by factoring out the entire first half of the method into its own private helper method.

```swift
private func fetchRequest(
   forTitle title: String,
   dateInterval: DateInterval?
) -> URLRequest? {
   var urlComponents = URLComponents(
      url: baseURL,
      resolvingAgainstBaseURL: true)!
   urlComponents.queryItems = [URLQueryItem(name: "title", value: title)]

   if let dates = dateInterval {
      let dateFormatter = DateFormatter()
      dateFormatter.timeStyle = .none
      dateFormatter.dateStyle = .short
      let start = dateFormatter.string(from: dates.start)
      let end = dateFormatter.string(from: dates.end)
      urlComponents.queryItems?.append(contentsOf: [
         URLQueryItem(name: "startdate", value: start),
         URLQueryItem(name: "enddate", value: end)
      ])
   }

   guard let url = urlComponents.url else { return nil }

   return URLRequest(url: url)
}
```

Now the start of our fetch method is much more clear and simple.

```swift
guard
   let request = fetchRequest(forTitle: title, dateInterval: dateInterval)
   else {
      completion(.failure(.badURL))
      return
}
```

Most of this new helper method is taken up by parsing the optional `DateInterval`, which seems counter-intuitive. This is another good candidate for some refactoring, including making that `DateFormatter` into a property on the class instance; after all, if we're going to use it for several calls, it doesn't make sense to make the computer recreate it every time and clutter up our code.

```swift
let fetchDateFormatter: DateFormatter = {
   let formatter = DateFormatter()
   formatter.timeStyle = .none
   formatter.dateStyle = .short
   return formatter
}()

private func fetchRequest(
   forTitle title: String,
   dateInterval: DateInterval?
) -> URLRequest? {
   var urlComponents = URLComponents(
      url: baseURL,
      resolvingAgainstBaseURL: true)!
   urlComponents.queryItems = [
      URLQueryItem(name: "title", value: title),
   ]
   addDateIntervalQueryItems(to: &urlComponents.queryItems, for: dateInterval)
   guard let url = urlComponents.url else { return nil }

   return URLRequest(url: url)
}

private func addDateIntervalQueryItems(
   to queryItems: inout [URLQueryItem]?,
   for dateInterval: DateInterval?
) {
   guard let dates = dateInterval else { return }
   let start = fetchDateFormatter.string(from: dates.start)
   let end = fetchDateFormatter.string(from: dates.end)
   queryItems.append(contentsOf: [
      URLQueryItem(name: "startdate", value: start),
      URLQueryItem(name: "enddate", value: end)
   ])
}
```

Notice we're using an `inout` array of query items. This allows us to pass in our query items by reference, which simplifies the `fetchRequest` method syntax a bit from something like this:

```swift
if let dateQueryItems = dateIntervalQueryItems(for: dateInterval) {
    urlComponents.queryItems?.append(contentsOf: dateQueryItems)
}
```

...to this:

```swift
addDateIntervalQueryItems(to: &urlComponents.queryItems, for: dateInterval)
```

However, taking some inspiration from [John Sundell's excellent article about utility functions](https://www.swiftbysundell.com/articles/writing-small-utility-functions-in-swift/), we can simplify a bit more by writing an extension on `Array`:

```swift
extension Array {
   func transforming(_ transformation: (inout Self) -> Void) -> Self {
      var newArray = self
      transformation(&newArray)
      return newArray
   }

   func appending(_ elements: [Element]) -> Self {
      transforming { $0.append(contentsOf: elements) }
   }
}
```

...Negating the need for the (relative) complexity of `inout` at the (relatively) higher level of our `APIController` (and giving us a handy API that we could reuse in other scenarios!).

```swift
private func fetchRequest(
   forTitle title: String,
   dateInterval: DateInterval?
) -> URLRequest? {
   var urlComponents = URLComponents(
      url: baseURL,
      resolvingAgainstBaseURL: true)!
   urlComponents.queryItems = [URLQueryItem(name: "title", value: title)]
      .appending(dateIntervalQueryItems(for: dateInterval))
   guard let url = urlComponents.url else { return nil }

   return URLRequest(url: url)
}

private func dateIntervalQueryItems(
   for dateInterval: DateInterval?
) -> [URLQueryItem] {
   guard let dates = dateInterval else { return [] }
   let start = fetchDateFormatter.string(from: dates.start)
   let end = fetchDateFormatter.string(from: dates.end)
   return [
      URLQueryItem(name: "startdate", value: start),
      URLQueryItem(name: "enddate", value: end)
   ]
}
```

## Handling the Data Task

This one is a bit tricky, as we'll see. My first instinct is to factor out the `dataTask`'s completion handler entirely.

```swift
func fetchObject(
   withTitle title: String,
   dateInterval: DateInterval? = nil,
   completion: @escaping (Result<Object, NetworkError>) -> Void
) {
   guard
      let request = fetchRequest(forTitle: title, dateInterval: dateInterval)
      else {
         completion(.failure(.badURL))
         return
   }

   URLSession.shared.dataTask(
      with: request,
      completionHandler: handleDataResponse(data:response:error:)
   ).resume()
}

private func handleDataResponse(
   data: Data?,
   response: URLResponse?,
   error: Error?
) {
   if let error = error {
      completion(.failure(.other(error)))
      return
   }

   if let httpResponse = response as? HTTPURLResponse,
      !(200...299).contains(httpResponse.statusCode)
   {
      completion(.failure(.badResponse(code: httpResponse.statusCode)))
      return
   }

   guard let data = data else {
      completion(.failure(.noData))
      return
   }

   do {
      let object = try JSONDecoder().decode(Object.self, from: data)
      completion(.success(object))
   } catch {
      completion(.failure(.decodeError(error)))
   }
}
```

There are few things I love more about Swift than passing a method into another method as a closure. However, if you try this, you'll immediately notice our problem; the new helper method needs access to our `completion` closure!

For now, let's keep things simple and within a reasonable scope for the sake of keeping this post a reasonable length, if nothing else. Instead of using the completion handler within the response-handling method, we can have it simply return a `Result` type, which can then be handled within our original public-facing fetch method.

We can also make the method generic, allowing it to handle any entity that conforms to `Decodable`, meaning we could reuse it verbatim in this or in other projects.

```swift
private func decodeModel<Model: Decodable>(
   _ model: Model.Type,
   fromData data: Data?,
   response: URLResponse?,
   error: Error?
) -> Result<Model, NetworkError> {
   if let error = error {
      return .failure(.other(error))
   }

   if let httpResponse = response as? HTTPURLResponse,
      !(200...299).contains(httpResponse.statusCode)
   {
      return .failure(.badResponse(code: httpResponse.statusCode))
   }

   guard let data = data else {
      return .failure(.noData)
   }

   do {
      let object = try JSONDecoder().decode(Model.self, from: data)
      return .success(object)
   } catch {
      return .failure(.decodeError(error))
   }
}
```

This gives us our final fetch method:

```swift
func fetchObject(
   withTitle title: String,
   dateInterval: DateInterval? = nil,
   completion: @escaping (Result<Object, NetworkError>) -> Void
) {
   guard
      let request = fetchRequest(forTitle: title, dateInterval: dateInterval)
      else {
         completion(.failure(.badURL))
         return
   }
   URLSession.shared.dataTask(with: request)
   { [weak self] data, response, error in
      guard let self = self else {
         completion(.failure(.deallocatedAPIController))
         return
      }
      completion(self.decodeModel(
         Object.self,
         fromData: data,
         response: response,
         error: error))
   }.resume()
}
```

Most notably, we use `[weak self]` because we need to access `self.objectResult`, and without capturing `self` `weak`ly, the closure would hold a strong reference to `self`, which, in some rare circumstances, could lead to a memory leak.

When all is said and done, the top-level method `fetchObject` has been reduced in size by nearly 70%. This isn't necesarily all that meaningful, but by using helper methods with descriptive titles (`fetchObject`, which calls `fetchRequest(forTitle:)` (which in turn calls `dateIntervalQueryItems`) and `decodeModel(_:fromData:)`), it's much more simple for humans to grok.

We could of course go further with this in all sorts of ways. We could abstract away the use of `URLSession` and/or with a generic networking class that could handle all sorts of requests and result types, or we could even switch to using Combine's new networking publishers.

The most important takeaway, though, is that although the computer can handle the first version of our method just fine, taking a couple of minutes to factor things out a bit can help you (and any collaborators) in a multitude of ways in the long run, increasing readability, testability, and reusability.
