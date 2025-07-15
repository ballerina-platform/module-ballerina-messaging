import ballerina/test;

@test:Config
function testInMemoryMessageStoreRetrival() {
    InMemoryMessageStore store = new;
    Message? message = store->retrieve();
    test:assertEquals(message, (), "Expected no message in empty store");

    store->store("testMessage");
    message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.content, "testMessage");
}

@test:Config
function testInMemoryMessageStoreAcknowledgmentWithSuccess() {
    InMemoryMessageStore store = new;
    store->store("testMessage");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.content, "testMessage");

    error? ackResult = store->acknowledge(message.id, true);
    if ackResult is error {
        test:assertFail(string `Expected acknowledgment to succeed, but got error: ${ackResult.message()}`);
    }

    Message? retrievedMessage = store->retrieve();
    test:assertEquals(retrievedMessage, ());
}

@test:Config
function testInMemoryMessageStoreAcknowledgmentWithFailure() {
    InMemoryMessageStore store = new;
    store->store("testMessage");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.content, "testMessage");

    error? ackResult = store->acknowledge(message.id, false);
    if ackResult is error {
        test:assertFail(string `Expected acknowledgment to succeed, but got error: ${ackResult.message()}`);
    }

    Message? retrievedMessage = store->retrieve();
    if retrievedMessage is () {
        test:assertFail("Expected a message to be retrievable after failed acknowledgment");
    }
    test:assertEquals(retrievedMessage.content, "testMessage");
}

@test:Config
function testInMemoryMessageStoreAcknowledgmentWithInvalidId() {
    InMemoryMessageStore store = new;

    error? ackResult = store->acknowledge("invalid-id", true);
    if ackResult is () {
        test:assertFail("Expected acknowledgment to fail with invalid ID, but it succeeded");
    }

    test:assertEquals(ackResult.message(), "Message with the given ID not found or not in flight");
}

@test:Config
function testInMemoryMessageStoreRetrivalsWithoutAck() {
    InMemoryMessageStore store = new;
    store->store("testMessage1");
    store->store("testMessage2");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.content, "testMessage1");

    message = store->retrieve();
    if message is () {
        test:assertFail("Expected a second message to be retrieved from the store");
    }
    test:assertEquals(message.content, "testMessage2");

    message = store->retrieve();
    test:assertEquals(message, ());
}

@test:Config
function testInMemoryMessageStoreRetrivalsWithDelayedSuccessAck() {
    InMemoryMessageStore store = new;
    store->store("testMessage");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.content, "testMessage");
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

@test:Config
function testInMemoryMessageStoreRetrivalsWithDelayedFailureAck() {
    InMemoryMessageStore store = new;
    store->store("testMessage");

    Message? message = store->retrieve();
    if message is () {
        test:assertFail("Expected a message to be retrieved from the store");
    }
    test:assertEquals(message.content, "testMessage");
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
    test:assertEquals(message.content, "testMessage");
}
