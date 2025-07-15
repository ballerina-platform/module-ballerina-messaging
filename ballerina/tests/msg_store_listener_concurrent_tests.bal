import ballerina/lang.runtime;
import ballerina/test;

final InMemoryMessageStore store2 = new;
final InMemoryMessageStore deadLetterStore2 = new;

isolated User[] users2 = [];

listener StoreListener storeListener2 = new (
    messageStore = store2,
    pollingInterval = 5,
    maxRetries = 1,
    retryInterval = 2,
    deadLetterStore = deadLetterStore2
);

service on storeListener2 {

    isolated remote function onMessage(anydata message) returns error? {
        User user = check message.toJson().fromJsonWithType();
        if user.age < 30 {
            runtime:sleep(20);
        }
        lock {
            users2.push(user.clone());
        }
    }
}

@test:BeforeSuite
function addMessagesToStore2() returns error? {
    foreach anydata message in messages {
        store2->store(message);
    }
}

@test:Config
function testMessageStoreListener2() returns error? {
    runtime:sleep(60);

    lock {
        test:assertEquals(users2, [
                    {name: "Alice", age: 30},
                    {name: "Charlie", age: 35},
                    {name: "Bob", age: 25}
                ], "Processed users do not match expected values");
    }

    testMessagesInDLS(deadLetterStore2, [
                "Dummy message",
                "Invalid message",
                {name: "Dave"}
            ]);
}
