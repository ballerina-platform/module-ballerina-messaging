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

@test:Config {
    groups: ["inmemoryStoreTests"]
}
function testInMemoryMessageStoreRetrieval() {
    InMemoryMessageStore store = new;
    Message? message = store->retrieve();
    test:assertEquals(message, (), "Expected no message in empty store");

    store->store("testMessage");
    message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.payload, "testMessage");
}

@test:Config {
    groups: ["inmemoryStoreTests"]
}
function testInMemoryMessageStoreAcknowledgmentWithSuccess() {
    InMemoryMessageStore store = new;
    store->store("testMessage");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.payload, "testMessage");

    error? ackResult = store->acknowledge(message.id, true);
    if ackResult is error {
        test:assertFail(string `Expected acknowledgment to succeed, but got error: ${ackResult.message()}`);
    }

    Message? retrievedMessage = store->retrieve();
    test:assertEquals(retrievedMessage, ());
}

@test:Config {
    groups: ["inmemoryStoreTests"]
}
function testInMemoryMessageStoreAcknowledgmentWithFailure() {
    InMemoryMessageStore store = new;
    store->store("testMessage");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.payload, "testMessage");

    error? ackResult = store->acknowledge(message.id, false);
    if ackResult is error {
        test:assertFail(string `Expected acknowledgment to succeed, but got error: ${ackResult.message()}`);
    }

    Message? retrievedMessage = store->retrieve();
    if retrievedMessage is () {
        test:assertFail("Expected a message to be retrievable after failed acknowledgment");
    }
    test:assertEquals(retrievedMessage.payload, "testMessage");
}

@test:Config {
    groups: ["inmemoryStoreTests"]
}
function testInMemoryMessageStoreAcknowledgmentWithInvalidId() {
    InMemoryMessageStore store = new;

    error? ackResult = store->acknowledge("invalid-id", true);
    if ackResult is () {
        test:assertFail("Expected acknowledgment to fail with invalid ID, but it succeeded");
    }

    test:assertEquals(ackResult.message(), "Message with the given ID not found or not in flight");
}

@test:Config {
    groups: ["inmemoryStoreTests"]
}
function testInMemoryMessageStoreRetrievalsWithoutAck() {
    InMemoryMessageStore store = new;
    store->store("testMessage1");
    store->store("testMessage2");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.payload, "testMessage1");

    message = store->retrieve();
    if message is () {
        test:assertFail("Expected a second message to be retrieved from the store");
    }
    test:assertEquals(message.payload, "testMessage2");

    message = store->retrieve();
    test:assertEquals(message, ());
}

@test:Config {
    groups: ["inmemoryStoreTests"]
}
function testInMemoryMessageStoreRetrievalsWithDelayedSuccessAck() {
    InMemoryMessageStore store = new;
    store->store("testMessage");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.payload, "testMessage");
    string id = message.id;

    message = store->retrieve();
    test:assertEquals(message, ());

    error? ackResult = store->acknowledge(id, true);
    if ackResult is error {
        test:assertFail(string `Expected acknowledgment to succeed, but got error: ${ackResult.message()}`);
    }

    message = store->retrieve();
    test:assertEquals(message, ());
}

@test:Config {
    groups: ["inmemoryStoreTests"]
}
function testInMemoryMessageStoreRetrievalsWithDelayedFailureAck() {
    InMemoryMessageStore store = new;
    store->store("testMessage");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.payload, "testMessage");
    string id = message.id;

    message = store->retrieve();
    test:assertEquals(message, ());

    error? ackResult = store->acknowledge(id, false);
    if ackResult is error {
        test:assertFail(string `Expected acknowledgment to succeed, but got error: ${ackResult.message()}`);
    }

    message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrievable after failed acknowledgment");
    }
    test:assertEquals(message.payload, "testMessage");
}
