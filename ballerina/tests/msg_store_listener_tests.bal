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

import ballerina/test;

final InMemoryMessageStore store1 = new;
final InMemoryMessageStore deadLetterStore1 = new;

isolated User[] users1 = [];

listener StoreListener storeListener1 = new (
    messageStore = store1,
    pollingInterval = 5,
    maxRetries = 1,
    retryInterval = 2,
    deadLetterStore = deadLetterStore1
);

type User record {
    string name;
    int age;
};

isolated boolean testForError = true;

service on storeListener1 {

    isolated remote function onMessage(anydata message) returns error? {
        lock {
            if testForError {
                testForError = false;
                return error("Simulated processing error");
            }
        }
        User user = check message.toJson().fromJsonWithType();
        lock {
            users1.push(user.clone());
        }
    }
}

const messages = [
    {name: "Alice", age: 30},
    "Dummy message",
    {name: "Bob", age: 25},
    "Invalid message",
    {name: "Charlie", age: 35},
    {name: "Dave"}
];

function addMessagesToStore1() returns error? {
    foreach anydata message in messages {
        store1->store(message);
    }
}

@test:Config
function testMessageStoreListener1() {
    lock {
        test:assertEquals(users1, [
                    {name: "Alice", age: 30},
                    {name: "Bob", age: 25},
                    {name: "Charlie", age: 35}
                ], "Processed users do not match expected values");
    }

    testMessagesInDLS(deadLetterStore1, [
                "Dummy message",
                "Invalid message",
                {name: "Dave"}
            ]);
}

function testMessagesInDLS(InMemoryMessageStore deadLetterStore, anydata[] expectedMessages) {
    foreach anydata message in expectedMessages {
        Message? failedMsg = deadLetterStore->retrieve();
        if failedMsg is () {
            test:assertFail("Expected a message in the dead letter store, but found none");
        }
        test:assertEquals(failedMsg.content, message);
    }
}

@test:Config
function testStoreListenerConfigValidation() {
    StoreListener|error storeListener = new (new InMemoryMessageStore(), pollingInterval = 0);
    if storeListener is StoreListener {
        test:assertFail("Expected an error due to invalid polling interval, but got a valid listener");
    }
    test:assertEquals(storeListener.message(), "pollingInterval must be greater than zero");

    storeListener = new (new InMemoryMessageStore(), maxRetries = -1);
    if storeListener is StoreListener {
        test:assertFail("Expected an error due to invalid max retries, but got a valid listener");
    }
    test:assertEquals(storeListener.message(), "maxRetries must be greater than or equal to zero");

    storeListener = new (new InMemoryMessageStore(), retryInterval = 0);
    if storeListener is StoreListener {
        test:assertFail("Expected an error due to invalid retry interval, but got a valid listener");
    }
    test:assertEquals(storeListener.message(), "retryInterval must be greater than zero");
}

@test:Config
function testStoreListenerLifeCycleTests() returns error? {
    StoreListener storeListener = check new (new InMemoryMessageStore());
    StoreService svc = service object {
        isolated remote function onMessage(anydata message) returns error? {
            // Simulate processing logic
            return;
        }
    };

    error? startResult = storeListener.'start();
    if startResult is error {
        test:assertFail("Failed to start StoreListener: " + startResult.message());
    }

    error? detachResult = storeListener.detach(svc);
    if detachResult is () {
        test:assertFail("Expected an error when detaching a service that is not attached, but got success");
    }
    test:assertEquals(detachResult.message(), "no service is attached");

    error? immediateStopResult = storeListener.immediateStop();
    if immediateStopResult is error {
        test:assertFail("Failed to immediately stop StoreListener: " + immediateStopResult.message());
    }

    error? attachResult = storeListener.attach(svc);
    if attachResult is error {
        test:assertFail("Failed to attach service to StoreListener: " + attachResult.message());
    }

    StoreService differentSvc = service object {
        isolated remote function onMessage(anydata message) returns error? {
            // Simulate different processing logic
            return;
        }
    };

    attachResult = storeListener.attach(differentSvc);
    if attachResult is () {
        test:assertFail("Expected an error when attaching the service again, but got success instead");
    }
    test:assertEquals(attachResult.message(), "service is already attached. Only one service " + 
        "can be attached to the message store listener");

    detachResult = storeListener.detach(differentSvc);
    if detachResult is () {
        test:assertFail("Expected an error when detaching a different service, but got success");
    }
    test:assertEquals(detachResult.message(), "the provided service is not attached to the listener");


    detachResult = storeListener.detach(svc);
    if detachResult is error {
        test:assertFail("Failed to detach service from StoreListener: " + detachResult.message());
    }

    attachResult = storeListener.attach(differentSvc);
    if attachResult is error {
        test:assertFail("Failed to attach different service to StoreListener: " + attachResult.message());
    }

    startResult = storeListener.'start();
    if startResult is error {
        test:assertFail("Failed to start StoreListener after attaching a different service: " + startResult.message());
    }

    immediateStopResult = storeListener.immediateStop();
    if immediateStopResult is error {
        test:assertFail("Failed to immediately stop StoreListener: " + immediateStopResult.message());
    }
}

Store customStore = isolated client object {
    final readonly & (string|error)[] data = ["message1", error("This is a mock error"), "message3"];
    private int counter = 0;

    isolated remote function store(anydata message) returns error? {
        // Not implemented for listener tests
        // Using a inbuilt array to simulate storage
    }

    isolated remote function retrieve() returns Message|error? {
        lock {
            if self.counter >= self.data.length() {
                return;
            }
            string|error content = self.data[self.counter];
            self.counter += 1;
            return content is string ?
                {id: string `msg${self.counter}`, content} :
                content;
        }
    }

    isolated remote function acknowledge(string id, boolean success = true) returns error? {
        // Acknowledge is not supported
        return error Error("acknowledge is not supported in CustomStore");
    }
};

listener StoreListener customStoreListener = new (
    messageStore = customStore,
    pollingInterval = 5,
    maxRetries = 1,
    retryInterval = 2
);

isolated int counter = 0;

service on customStoreListener {

    isolated remote function onMessage(anydata message) returns error? {
        lock {
            counter += 1;
        }
    }
}

@test:Config
function testListenerNegativeBehaviorWithCustomStore() {
    lock {
        test:assertEquals(counter, 2);
    }
}

Store customDeadLetterStore = isolated client object {
    isolated remote function store(anydata message) returns error? {
        return error Error("store is not supported in CustomDeadLetterStore");
    }

    isolated remote function retrieve() returns Message|error? {
        // Not needed for this test
        return;
    }

    isolated remote function acknowledge(string id, boolean success = true) returns error? {
        // Not needed for this test
    }
};

isolated client class TestStore {
    *Store;

    private boolean? lastAckStatus = ();
    private boolean isRetrieveCalled = false;

    isolated remote function acknowledge(string id, boolean success) returns error? {
        lock {
            self.lastAckStatus = success;
        }
        return;
    }

    isolated remote function retrieve() returns Message|error? {
        lock {
            if self.isRetrieveCalled {
                return;
            }
            self.isRetrieveCalled = true;
            return {id: "test", content: "testContent"};
        }
    }

    isolated remote function store(anydata message) returns error? {
        // Not needed for this test
    }

    isolated function getLastAckStatus() returns boolean? {
        lock {
            return self.lastAckStatus;
        }
    }
}

TestStore testStore1 = new;
TestStore testStore2 = new;

listener StoreListener customDeadLetterStoreListenerWithDrop = new (
    messageStore = testStore1,
    pollingInterval = 5,
    maxRetries = 1,
    retryInterval = 2,
    deadLetterStore = customDeadLetterStore,
    dropMessageAfterMaxRetries = true
);

listener StoreListener customDeadLetterStoreListenerWithoutDrop = new (
    messageStore = testStore2,
    pollingInterval = 5,
    maxRetries = 1,
    retryInterval = 2,
    deadLetterStore = customDeadLetterStore,
    dropMessageAfterMaxRetries = false
);

service on customDeadLetterStoreListenerWithDrop, customDeadLetterStoreListenerWithoutDrop {

    isolated remote function onMessage(anydata message) returns error? {
        return error("Simulated processing error");
    }
}

@test:Config
function testDeadLetterStoreFailure() {
    test:assertEquals(testStore1.getLastAckStatus(), true, "Expected message to be acknowledged after max retries with drop enabled");
    test:assertEquals(testStore2.getLastAckStatus(), false, "Expected message to be acknowledged after max retries without drop enabled");
}
