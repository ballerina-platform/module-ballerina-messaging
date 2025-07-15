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

# Represents the message content with a unique consumer ID.
public type Message record {|
    # The unique identifier used by the consumer to acknowledge the message
    readonly string id;
    # The actual message content
    anydata content;
|};

# Represents a message store interface for storing and retrieving messages.
public type Store isolated client object {

    # Stores a message in the message store.
    #
    # + message - The message to be stored
    # + return - An error if the message could not be stored, or `()`
    isolated remote function store(anydata message) returns error?;

    # Retrieves the top message from the message store without removing it.
    #
    # + return - The retrieved message, or `()` if the store is empty, or an error if an error occurs
    isolated remote function retrieve() returns Message|error?;

    # Acknowledges the top message retrieved from the message store.
    #
    # + id - The unique identifier of the message to acknowledge. This should be the same as the `id`
    # of the message retrieved from the store
    # + success - Indicates whether the message was processed successfully or not
    # + return - An error if the acknowledgment could not be processed, or `()`
    isolated remote function acknowledge(string id, boolean success = true) returns error?;
};
