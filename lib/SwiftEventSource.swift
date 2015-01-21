//
//  SwiftEventSource.swift
//  SwiftEvenSourceDemo
//
//  Created by Haris Amin on 1/21/15.
//  Copyright (c) 2015 Haris Amin. All rights reserved.
//

import Foundation

let ESKeyValueDelimiter = ": "
let ESEventSeparatorLFLF = "\n\n"
let ESEventSeparatorCRCR = "\r\r"
let ESEventSeparatorCRLFCRLF = "\r\n\r\n"
let ESEventKeyValuePairSeparator = "\n"

let ESEventDataKey = "data"
let ESEventIDKey = "id"
let ESEventEventKey = "event"
let ESEventRetryKey = "retry"

// MARK: EventState
enum EventState : Printable {
    case CONNECTING;
    case OPEN;
    case CLOSED;
    
    var description : String {
        switch self {
        case .CONNECTING: return "CONNECTING";
        case .OPEN: return "OPEN";
        case .CLOSED: return "CLOSED";
        }
    }
}

// MARK: EventType
enum EventType : Printable {
    case MESSAGE;
    case ERROR;
    case OPEN;
    
    var description : String {
        switch self {
        case .MESSAGE: return "MESSAGE";
        case .ERROR: return "ERROR";
        case .OPEN: return "OPEN";
        }
    }
}

struct Event{
    var eventId:String? = nil
    var event:String? = nil
    var data:String? = nil
    var error:NSError? = nil
    var readyState:EventState = EventState.CLOSED
}

typealias EventSourceHandler = (Event) -> Void

class EventSource: NSObject, NSURLConnectionDelegate, NSURLConnectionDataDelegate {
    private var eventURL:NSURL?
    private var eventSourceConnection:NSURLConnection?
    private var listeners = Dictionary<String, [EventSourceHandler]>()
    private var timeoutInterval:NSTimeInterval = 300.0
    private var retryInterval:NSTimeInterval = 1.0
    private var lastEventID:String?
    
    private var wasClosed:Bool = true

//    /// Provides details of any errors with the connection to the EventSource
//    @property (nonatomic, strong) NSError *error;
    
    init(url:String) {
        self.eventURL = NSURL(string: url)
        super.init()
        
        let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(self.retryInterval * Double(NSEC_PER_SEC)))
        dispatch_after(popTime, dispatch_get_main_queue()) {
            self.open()
        }
    }
    
    func open(){
        self.wasClosed = false
        var request = NSMutableURLRequest(URL: self.eventURL!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: self.timeoutInterval)
        if(self.lastEventID != nil){
            request.setValue(self.lastEventID, forHTTPHeaderField: "Last-Event-ID")
        }
        self.eventSourceConnection = NSURLConnection(request: request, delegate: self, startImmediately: true)
    }
    
    func close(){
        self.wasClosed = true
        self.eventSourceConnection?.cancel()
    }
    
    func addEventListener(eventName:String, handler:EventSourceHandler){
        if(self.listeners[eventName] == nil){
            self.listeners[eventName] = []
        }
        self.listeners[eventName]!.append(handler)
    }
    
    func onMessage(handler:EventSourceHandler){
        self.addEventListener(EventType.MESSAGE.description, handler: handler)
    }
    
    func onError(handler:EventSourceHandler){
        self.addEventListener(EventType.ERROR.description, handler: handler)
    }
    
    func onOpen(handler:EventSourceHandler){
        self.addEventListener(EventType.OPEN.description, handler: handler)
    }
    
    // MARK: NSURLConnectionDelegate
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        let httpResponse = response as NSHTTPURLResponse
        
        if(httpResponse.statusCode == 200){
            // Opened
            var event = Event()
            event.readyState = EventState.OPEN
            if let openHandlers:[EventSourceHandler] = self.listeners[EventType.OPEN.description]{
                for handler in openHandlers{
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        handler(event)
                    })
                }
            }
            

        }
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        //
        var event = Event()
        event.readyState = EventState.CLOSED
        event.error = error
        if let errorHandlers:[EventSourceHandler] = self.listeners[EventType.ERROR.description]{
            for handler in errorHandlers{
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    handler(event)
                })
            }
            
            let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(self.retryInterval * Double(NSEC_PER_SEC)))
            dispatch_after(popTime, dispatch_get_main_queue()) {
                self.open()
            }
        }

    }
    
    // MARK: NSURLConnectionDataDelegate
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        var eventString = NSString(data: data, encoding: NSUTF8StringEncoding)
        
        if( eventString!.hasSuffix(ESEventSeparatorLFLF) ||
            eventString!.hasSuffix(ESEventSeparatorCRCR) ||
            eventString!.hasSuffix(ESEventSeparatorCRLFCRLF) ) {
        
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
                eventString = eventString!.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
                let components = eventString?.componentsSeparatedByString(ESEventKeyValuePairSeparator) as [NSString]
                var event = Event()
                event.readyState = EventState.OPEN
                
                for component in components{
                    if(component.length == 0){
                        continue
                    }
                    
                    let index = component.rangeOfString(ESKeyValueDelimiter).location
                    if (index == NSNotFound || index == (component.length - 2)) {
                        continue;
                    }
                    
                    let key = component.substringToIndex(index)
                    let countForKeyValueDelimimter = countElements(ESKeyValueDelimiter)
                    let value = component.substringFromIndex(index + countForKeyValueDelimimter)
                    
                    if ( key == ESEventIDKey) {
                        event.eventId = value;
                        self.lastEventID = event.eventId;
                    } else if (key == ESEventEventKey) {
                        event.event = value;
                    } else if (key == ESEventDataKey) {
                        event.data = value;
                    } else if (key == ESEventRetryKey) {
//                        self.retryInterval = Double(value);
                    }
                }
                
                if let messageHandlers:[EventSourceHandler] = self.listeners[EventType.MESSAGE.description]{
                    for handler in messageHandlers{
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            handler(event)
                        })
                    }
                }

                
                if(event.event != nil){
                    if let namedEventhandlers:[EventSourceHandler] = self.listeners[event.event!]{
                        for handler in namedEventhandlers{
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                handler(event)
                            })
                        }
                    }

                }
                
            })
        }

    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        if(self.wasClosed){
            return
        }
        var event = Event()
        event.readyState = EventState.CLOSED
        event.error = NSError(domain: "", code: 2, userInfo: [NSLocalizedDescriptionKey: "Connection with the event source was closed."])
        if let errorHandlers:[EventSourceHandler] = self.listeners[EventType.ERROR.description]{
            for handler in errorHandlers{
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    handler(event)
                })
            }
            self.open()
        }
    }
    
    
}