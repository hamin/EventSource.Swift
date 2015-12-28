# EventSource.Swift

[![Join the chat at https://gitter.im/hamin/EventSource.Swift](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/hamin/EventSource.Swift?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

![swift](https://raw.githubusercontent.com/hamin/EventSource.Swift/master/swift-logo.png)


A simple Swift client library for the [Server Side Events](http://www.w3.org/TR/eventsource/) also known as [SSE](http://en.wikipedia.org/wiki/Server-sent_events). 

EventSource.Swift is an client implementation of the [HTML 5 EventSource API that allows browsers respond to SSE event-streams](http://www.w3schools.com/htmL/html5_serversentevents.asp) EventSource. 

Swift will work on both OSX and iOS.

It was heavily inspired by the Objective-C client found here: [EventSource](https://github.com/neilco/EventSource)

If you're interested in EventSource.Swift, you might be interested in [FayeSwift](http://github.com/hamin/FayeSwift) too. I wrote this client with the intention of adding a SSE transport for [FayeSwift](http://github.com/hamin/FayeSwift), a swift [Faye](http://faye.jcoglan.com/) client. [FayeSwift](http://github.com/hamin/FayeSwift) currently only websocket transports.

## Example

### Installation

For now, add `EventSource.swift` to your project.

### Initializing Client

You can open a connection to your faye server.

```swift
var source = EventSource(url: "http://127.0.0.1:8000/")
```

You can then add an event listener for any event:

```swift
source.addEventListener("hello_event", handler: { (e:Event) -> Void in
    println("Event: \(e.event) Data: \(e.data)")
})
```

After you are connected, there are some optional delegate methods that we can implement.

### Subscribing to EventTypes

You can subscribe to the following `EventTypes` to observer all respective data as it comes in:

#### Open
```swift
source.onOpen { (e:Event) -> Void in
    println("Connection opened!")
}
```

#### Error
```swift
source.onError { (e:Event) -> Void in
    println("Error: \(e.error?.userInfo)")
}
```

#### Message
```swift
source.onMessage { (e:Event) -> Void in
    println("Message: \(e.data)");
}
```

### EventSourceDelegate

First set the delegate on the `EventSource` instance:

```swift
source.delegate = self
```

You can then implement the `EventSourceDelegate` in addition or instead of the callback handlers mentioned above.



#### eventSourceOpenedConnection

```swift
func eventSourceOpenedConnection(event: Event) {
    println("DELEGATE: OPENED CONNECTION")
}
```

#### eventSourceReceivedError

```swift
func eventSourceReceivedError(event: Event, error: NSError) {
    println("DELEGATE: Received Error: \(error)")
}
```

#### eventSourceReceivedMessage

```swift
func eventSourceReceivedMessage(event: Event, message: NSDictionary) {
    println("DELEGATE: RECEIVED MESSAGE: \(message)")
}
```

## Example Server

There is a sample EventSource server using the NodeJS Faye library. If you have NodeJS just start the server like so:

```javascript
node server.js
```
## Example Project

Check out the EventSourceSwiftDemo project to see how to setup a simple connection to a EventSource server.

## Requirements

EventSource.Swift requires at least iOS 7/OSX 10.10 or above.

## TODOs

- [x] Replace NSURLConnection with NSURLSession
- [ ] Cocoapods Integration
- [ ] Complete Docs
- [ ] Add Unit Tests

## License

EventSource.Swift is licensed under the MIT License.
