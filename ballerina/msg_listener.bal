// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/lang.runtime;
import ballerina/log;
import ballerina/task;

# Represents the default error type.
public type Error distinct error;

# Represents the message store listener configuration,
public type StoreListenerConfiguration record {|
    # The interval in seconds at which the listener polls for new messages
    decimal pollingInterval = 1;
    # The maximum number of retries for processing a message. 
    # If set to 0, the message will not be retried
    int maxRetries = 3;
    # The interval in seconds between retries for processing a message
    decimal retryInterval = 1;
    # If true, the message will be dropped after the maximum number of retries is reached
    boolean dropMessageAfterMaxRetries = false;
    # An optional message store to store messages that could not be processed after the maximum 
    # number of retries. When set, `dropMessageAfterMaxRetries` will be ignored
    Store deadLetterStore?;
|};

# Represents a message store listener that polls messages from a message store and processes them.
public isolated class StoreListener {

    private Store messageStore;
    private StoreService? messageStoreService = ();
    private task:JobId? pollJobId = ();
    private final StoreListenerConfiguration config;

    # Initializes a new instance of Message Store Listener.
    #
    # + messageStore - The message store to retrieve messages from
    # + config - The configuration for the message store listener
    # + return - An error if the listener could not be initialized, or `()`
    public isolated function init(Store messageStore, *StoreListenerConfiguration config) returns Error? {
        self.messageStore = messageStore;
        if config.maxRetries < 0 {
            return error Error("maxRetries cannot be negative");
        }
        if config.pollingInterval <= 0d {
            return error Error("pollingInterval must be greater than zero");
        }
        if config.retryInterval <= 0d {
            return error Error("retryInterval must be greater than zero");
        }
        StoreListenerConfiguration {deadLetterStore, ...otherConfig} = config;
        self.config = {
            ...otherConfig.clone(),
            deadLetterStore
        };
    }

    # Attaches a message store service to the listener. Only one service can be attached to this 
    # listener.
    #
    # + msgStoreService - The message store service to attach
    # + path - The path is not relevant for this listener. Only allowing a nil value
    # + return - An error if the service could not be attached, or a nil value
    public isolated function attach(StoreService msgStoreService, () path = ()) returns Error? {
        lock {
            if self.messageStoreService is StoreService {
                return error Error("service is already attached. Only one service can be " +
                    "attached to the message store listener");
            }
            self.messageStoreService = msgStoreService;
        }
    }

    # Detaches the message store service from the listener.
    #
    # + msgStoreService - The message store service to detach
    # + return - An error if the service could not be detached, or a nil value
    public isolated function detach(StoreService msgStoreService) returns Error? {
        lock {
            task:JobId? pollJobId = self.pollJobId;
            if pollJobId is task:JobId {
                error? stopResult = task:unscheduleJob(pollJobId);
                if stopResult is Error {
                    return error Error("failed to detach the service", cause = stopResult);
                }
            }

            StoreService? currentService = self.messageStoreService;
            if currentService is () {
                return error Error("no service is attached");
            }
            if currentService === msgStoreService {
                self.messageStoreService = ();
            } else {
                return error Error("the provided service is not attached to the listener");
            }
        }
    }

    # Starts the message store listener to poll and process messages.
    #
    # + return - An error if the listener could not be started, or a nil value
    public isolated function 'start() returns Error? {
        lock {
            StoreService? currentService = self.messageStoreService;
            if currentService is () || self.pollJobId !is () {
                return;
            }

            PollAndProcessMessages pollTask = new (self.messageStore, currentService, self.config);
            task:JobId|error pollJob = task:scheduleJobRecurByFrequency(pollTask, self.config.pollingInterval);
            if pollJob is error {
                return error Error("failed to start message store listener", cause = pollJob);
            }
        }
    }

    # Gracefully stops the message store listener by waiting for any ongoing processing to 
    # complete before stopping. This is not implemented yet, and currently this will call 
    # immediateStop.
    #
    # + return - An error if the listener could not be stopped, or a nil value
    public isolated function gracefulStop() returns Error? {
        return self.immediateStop();
    }

    # Immediately stops the message store listener without waiting for any ongoing processing 
    # to complete.
    #
    # + return - An error if the listener could not be stopped, or `()`.
    public isolated function immediateStop() returns Error? {
        lock {
            task:JobId? pollJobId = self.pollJobId;
            if pollJobId is () {
                return;
            }

            error? stopResult = task:unscheduleJob(pollJobId);
            if stopResult is error {
                return error Error("failed to stop message store listener", cause = stopResult);
            }
        }
    }

}

isolated class PollAndProcessMessages {
    *task:Job;

    private final Store messageStore;
    private final StoreService messageStoreService;
    private final readonly & record {*StoreListenerConfiguration; never deadLetterStore?;} config;
    private Store? deadLetterStore = ();

    public isolated function init(Store messageStore, StoreService messageStoreService,
            StoreListenerConfiguration config) {
        self.messageStore = messageStore;
        self.messageStoreService = messageStoreService;
        StoreListenerConfiguration {deadLetterStore, ...otherConfig} = config;
        self.deadLetterStore = deadLetterStore;
        self.config = otherConfig.cloneReadOnly();
    }

    public isolated function ackMessage(string id, boolean success = true) {
        error? result = self.messageStore->acknowledge(id, success);
        if result is error {
            log:printError("failed to acknowledge message", 'error = result);
        }
    }

    public isolated function execute() {
        Message|error? message = self.messageStore->retrieve();
        if message is error {
            log:printError("error occurred while polling for the message", 'error = message);
            return;
        }
        if message is () {
            return;
        }

        anydata content = message.content;
        string id = message.id;

        error? result = trap self.messageStoreService->onMessage(content);
        if result is () {
            self.ackMessage(id);
            return;
        }
        log:printError("error processing message", 'error = result);

        if self.config.maxRetries > 0 {
            foreach int attempt in 1 ... self.config.maxRetries {
                runtime:sleep(self.config.retryInterval);
                error? retryResult = self.messageStoreService->onMessage(content);
                if retryResult is error {
                    log:printError("error processing message on retry", retryAttempt = attempt, 'error = retryResult);
                } else {
                    log:printDebug("message processed successfully on retry", retryAttempt = attempt, id = id);
                    self.ackMessage(id);
                    return;
                }
            }
        }
        Store? dls;
        lock {
            dls = self.deadLetterStore;
        }
        if dls is Store {
            error? dlsResult = dls->store(content.clone());
            if dlsResult is error {
                log:printError("failed to store message in dead letter store", 'error = dlsResult);
            } else {
                log:printDebug("message stored in dead letter store after max retries", payload = message);
                self.ackMessage(id);
                return;
            }
        }

        if self.config.dropMessageAfterMaxRetries {
            log:printDebug("max retries reached, dropping message", payload = message);
        }
        else {
            log:printDebug("max retries reached, message is kept in the store", payload = message);
        }
        self.ackMessage(id, self.config.dropMessageAfterMaxRetries);
    }
}
