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
enum EventState : CustomStringConvertible {
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
enum EventType : CustomStringConvertible {
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

class Event: NSObject{
    var eventId:String? = nil
    var event:String? = nil
    var data:String? = nil
    var error:NSError? = nil
    var readyState:EventState = EventState.CLOSED
}

typealias EventSourceHandler = (Event) -> Void

@objc protocol EventSourceDelegate{
    optional func eventSourceOpenedConnection(event:Event)
    optional func eventSourceReceivedError(event:Event, error:NSError)
    optional func eventSourceReceivedMessage(event:Event, message: String)
}

class EventSource: NSObject, NSURLSessionDataDelegate {
    private var eventURL:NSURL?
    private var eventSourceTask:NSURLSessionDataTask?
    private var listeners = Dictionary<String, [EventSourceHandler]>()
    private var timeoutInterval:NSTimeInterval = 300.0
    private var retryInterval:NSTimeInterval = 1.0
    private var lastEventID:String?
    private var wasClosed:Bool = true
    
    weak var delegate:EventSourceDelegate?
    
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
        let request = NSMutableURLRequest(URL: self.eventURL!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: self.timeoutInterval)
        if(self.lastEventID != nil){
            request.setValue(self.lastEventID, forHTTPHeaderField: "Last-Event-ID")
        }
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringCacheData
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        var additionalHeaders: [NSObject : AnyObject] = ["Accept":"text/event-stream", "Cache-Control": "no-cache"]
        if(self.lastEventID != nil){
            additionalHeaders["Last-Event-ID"] = self.lastEventID
        }
        configuration.HTTPAdditionalHeaders = additionalHeaders
        
        let session = NSURLSession(configuration: configuration, delegate: self, delegateQueue: NSOperationQueue())
        self.eventSourceTask = session.dataTaskWithRequest(request)
        self.eventSourceTask?.resume()
    }
    
    func close(){
        self.wasClosed = true
        self.eventSourceTask?.cancel()
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
    
    
    // MARK: NSURLSessionDataDelegate
    
    internal func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        var eventString = NSString(data: data, encoding: NSUTF8StringEncoding)

        if( eventString!.hasSuffix(ESEventSeparatorLFLF) ||
            eventString!.hasSuffix(ESEventSeparatorCRCR) ||
            eventString!.hasSuffix(ESEventSeparatorCRLFCRLF) ) {

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
                eventString = eventString!.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
                let components = eventString!.componentsSeparatedByString(ESEventKeyValuePairSeparator)
                let event = Event()
                event.readyState = EventState.OPEN

                for component in components{
                    if(component.characters.count == 0){
                        continue
                    }

                    let range = component.rangeOfString(ESKeyValueDelimiter)
                    let index: Int = component.startIndex.distanceTo(range!.startIndex)
                    if (index == NSNotFound || index == (component.characters.count - 2)) {
                        continue;
                    }

                    let keyIndex = component.startIndex.advancedBy(index)
                    let key = component.substringToIndex(keyIndex)
                    let countForKeyValueDelimimter = ESKeyValueDelimiter.characters.count
                    let valueIndex = component.startIndex.advancedBy(index + countForKeyValueDelimimter)
                    let value = component.substringToIndex(valueIndex)

                    if ( key == ESEventIDKey) {
                        event.eventId = value;
                        self.lastEventID = event.eventId;
                    } else if (key == ESEventEventKey) {
                        event.event = value;
                    } else if (key == ESEventDataKey) {
                        event.data = value;
                    } else if (key == ESEventRetryKey) {
                        self.retryInterval = (value as NSString).doubleValue
                    }
                }

                self.delegate?.eventSourceReceivedMessage?(event, message: eventString! as String)

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
    
    internal func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: ((NSURLSessionResponseDisposition) -> Void)) {
        completionHandler(NSURLSessionResponseDisposition.Allow)
        
        let httpResponse = response as! NSHTTPURLResponse

        if(httpResponse.statusCode == 200){
            // Opened
            let event = Event()
            event.readyState = EventState.OPEN

            self.delegate?.eventSourceOpenedConnection?(event)

            if let openHandlers:[EventSourceHandler] = self.listeners[EventType.OPEN.description]{
                for handler in openHandlers{
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        handler(event)
                    })
                }
            }
            

        }
    }
    
    internal func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        print("THERE IS AN ERROR: \(error)")
        let event = Event()
        event.readyState = EventState.CLOSED
        event.error = error

        self.delegate?.eventSourceReceivedError?(event, error: error!)

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
}