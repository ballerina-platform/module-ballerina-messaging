import ballerina/data.jsondata;
import ballerina/http;
import ballerina/log;
import ballerina/messaging;

// Main message store for incoming order requests
// In a real-world scenario, this would be a persistent store (e.g., RabbitMQ, Kafka, etc.)
final messaging:Store orderMessageStore = new messaging:InMemoryMessageStore();

// Dead Letter Queue(DLQ) store for messages that consistently fail processing
// In a real-world scenario, this would be a persistent store (e.g., RabbitMQ, Kafka, etc.)
final messaging:Store deadLetterStore = new messaging:InMemoryMessageStore();

// Listener for processing orders from the 'orderMessageStore'
// Configured for retries and DLQ
listener messaging:StoreListener orderProcessorListener = new(orderMessageStore, {
    pollingInterval: 5,        // Poll for new messages every 5 seconds
    maxRetries: 3,             // Retry processing an order up to 3 times
    retryInterval: 2,          // Wait 2 seconds between retries
    deadLetterStore: deadLetterStore // If max retries are exhausted, move to DLQ
});

// The Order record type represents the structure of an order message
public type Order record {|
    string orderId;
    string customerName;
    decimal amount;
|};

// A mock variable to simulate transient errors
isolated boolean returnTransientError = true;

// This service is attached to 'orderProcessorListener' and handles incoming orders.
service on orderProcessorListener {

    isolated remote function onMessage(anydata orderContent) returns error? {
        Order 'order = check jsondata:parseAsType(orderContent.toJson());
        log:printInfo("Processing order", orderContent = orderContent);

        // Simulate a transient processing failure for specific order contents
        // For example, an external inventory service might be temporarily down for "OrderXYZ"
        lock {
            if returnTransientError && 'order.orderId == "OrderXYZ" {
                returnTransientError = false; // Prevent further transient errors for this order
                error err = error("Inventory service unavailable for OrderXYZ");
                log:printError("Failed to process order", 'error = err, orderId = 'order.orderId);
                return err;
            }
        }

        // Simulate a consistent processing failure for "CriticalOrderABC" that always fails
        if 'order.orderId == "CriticalOrderABC" {
            error err = error("Invalid order data for CriticalOrderABC");
            log:printError("Failed to process order", 'error = err, orderId = 'order.orderId);
            return err;
        }

        // Simulate successful processing
        log:printInfo("Successfully processed order", orderId = 'order.orderId);
    }
}

// This HTTP service acts as the entry point for new order requests.
service /orders on new http:Listener(9090) {

    // Endpoint to accept new order requests and store them
    resource function post createOrder(Order 'order) returns http:Accepted|error {
        log:printInfo("Received new order", orderId = 'order.orderId, customerName = 'order.customerName, amount = 'order.amount);
        check orderMessageStore->store('order); // Store the order in our message store
        log:printInfo("Order stored successfully", orderId = 'order.orderId);
        return http:ACCEPTED;
    }
}
