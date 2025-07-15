# Ballerina Messaging Module

[![Build](https://github.com/ballerina-platform/module-ballerina-messaging/actions/workflows/build-timestamped-master.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-messaging/actions/workflows/build-timestamped-master.yml)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerina-messaging/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerina-messaging)
[![Trivy](https://github.com/ballerina-platform/module-ballerina-messaging/actions/workflows/trivy-scan.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-messaging/actions/workflows/trivy-scan.yml)
[![GraalVM Check](https://github.com/ballerina-platform/module-ballerina-messaging/actions/workflows/build-with-bal-test-graalvm.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-messaging/actions/workflows/build-with-bal-test-graalvm.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerina-messaging.svg)](https://github.com/ballerina-platform/module-ballerina-messaging/commits/main)
[![Github issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-standard-library/module/messaging.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-standard-library/labels/module%2Fmessaging)

The Ballerina Messaging module provides a message store interface and a message store listener to implement guaranteed message delivery in Ballerina applications.

## Message Store Interface

The `MessageStore` interface defines the fundamental contract for message persistence and retrieval. Implementations
of this interface allow Ballerina applications to interact with different message storage systems in a uniform manner.

```ballerina
# Represents the message content with a unique consumer ID.
public type Message record {|
    # The unique identifier for the message
    string id;
    # The actual message content
    anydata content;
|};

# Represents a message store interface for storing and retrieving messages.
public type MessageStore isolated client object {

    # Stores a message in the message store.
    #
    # + message - The message to be stored
    # + return - An error if the message could not be stored, or `()`
    isolated remote function store(anydata message) returns error?;

    # Retrieves the top message from the message store without removing it.
    #
    # + return - The retrieved message, or () if the store is empty, or an error if an error occurs
    isolated remote function retrieve() returns Message|error?;

    # Acknowledges the top message retrieved from the message store.
    #
    # + id - The unique identifier of the message to acknowledge. This should be the same as the `id`
    # of the message retrieved from the store.
    # + success - Indicates whether the message was processed successfully or not
    # + return - An error if the acknowledgment could not be processed, or `()`
    isolated remote function acknowledge(string id, boolean success = true) returns error?;
};
```

## Store Listener

The Store Listener is responsible for orchestrating message consumption from any `MessageStore` implementation.
It operates by polling the associated message store at configurable intervals and dispatching messages to an attached
service.

To initialize a listener, provide an instance of a `MessageStore`:

```ballerina
// Example using an in-memory store
messaging:MessageStore msgStore = new messaging:InMemoryMessageStore();

listener messaging:StoreListener msgStoreListener = new(msgStore);
```

The listener's behavior, including polling frequency, retry mechanisms, and dead-letter queue (DLQ) support,
can be customized using the listener configuration.

```ballerina
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
```

## Message Store Service

A message store service, defined by the `messaging:Service` type, can be attached to a `messaging:Listener` to
process messages retrieved from the message store. This service exposes a single remote method, `onMessage`, which is
invoked when a new message is received.

```ballerina
# This service object defines the contract for processing messages from a message store.
public type Service distinct isolated service object {

    # This remote function is called when a new message is received from the message store.
    #
    # + content - The message content to be processed
    # + return - An error if the message could not be processed, or a nil value
    isolated remote function onMessage(anydata content) returns error?;
};
```

If the `onMessage` function returns an `error`, the message processing will be retried based on the configured
`maxRetries` and `retryInterval`. If the maximum retries are exhausted and a `deadLetterStore` is configured, the
message will be moved to the dead-letter store.

## Example

The following example demonstrates how to utilize this package to set up an in-memory message store and a listener to
process messages:

```ballerina
import ballerina/http;
import ballerina/io;
import ballerina/messaging;

// Initialize an in-memory message store
messaging:MessageStore msgStore = new messaging:InMemoryMessageStore();

// Initialize a message store listener with custom configuration
listener messaging:Listener msgStoreListener = new(msgStore, {
    pollingInterval: 10,  // Poll every 10 seconds
    maxRetries: 2,        // Retry message processing up to 2 times
    retryInterval: 2      // Wait 2 seconds between retries
});

// Define and attach a service to the listener to handle incoming messages
service on msgStoreListener {

    isolated remote function onMessage(anydata content) returns error? {
        io:println("Received message: ", content);

        // Simulate a processing failure for specific message content
        if content is string && content == "fail" {
            return error("Message processing failed due to 'fail' content");
        }
        // If no error is returned, the message is acknowledged as successfully processed
    }
}

// Defines an HTTP service to produce messages to the message store
service /api/v1 on new http:Listener(8080) {

    // Endpoint to send messages to the message store
    resource function post messages(@http:Payload anydata content) returns http:Accepted|error {
        check msgStore.store(content);
        return http:ACCEPTED;
    }
}
```

## Issues and projects

The **Issues** and **Projects** tabs are disabled for this repository as this is part of the Ballerina library. To report bugs, request new features, start new discussions, view project boards, etc., visit the Ballerina library [parent repository](https://github.com/ballerina-platform/ballerina-library).

This repository only contains the source code for the package.

## Building from the source

### Prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

    - [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    - [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

   > **Note**: Ensure that the Docker daemon is running before executing any tests.

4. Generate a Github access token with read package permissions, then set the following `env` variables:

    ```bash
   export packageUser=<Your GitHub Username>
   export packagePAT=<GitHub Personal Access Token>
    ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To debug package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

5. To debug with Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

6. Publish the generated artifacts to the local Ballerina central repository:

   ```bash
   ./gradlew clean build -PpublishToLocalCentral=true
   ```

7. Publish the generated artifacts to the Ballerina central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contributing to Ballerina

As an open source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

- Discuss code changes of the Ballerina project in [ballerina-dev@googlegroups.com](mailto:ballerina-dev@googlegroups.com).
- Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
- Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
