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

function addMessagesToStore2() returns error? {
    foreach anydata message in messages {
        store2->store(message);
    }
}

@test:Config
function testMessageStoreListener2() {
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
