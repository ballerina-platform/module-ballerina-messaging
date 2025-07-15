import ballerina/lang.runtime;
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

service on storeListener1 {

    isolated remote function onMessage(anydata message) returns error? {
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

@test:BeforeSuite
function addMessagesToStore1() returns error? {
    foreach anydata message in messages {
        store1->store(message);
    }
}

@test:Config
function testMessageStoreListener1() returns error? {
    runtime:sleep(60);

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
