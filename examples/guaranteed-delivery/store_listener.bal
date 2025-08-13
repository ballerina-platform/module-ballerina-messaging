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

import ballerina/data.jsondata;
import ballerina/log;
import ballerina/messaging;

// Listener for processing orders from the 'orderMessageStore'
// Configured for retries and DLQ
listener messaging:StoreListener orderProcessorListener = new(orderMessageStore, {
    pollingInterval: 5,        // Poll for new messages every 5 seconds
    maxRetries: 3,             // Retry processing an order up to 3 times
    retryInterval: 2,          // Wait 2 seconds between retries
    deadLetterStore: deadLetterStore // If max retries are exhausted, move to DLQ
});

// A mock variable to simulate transient errors
isolated boolean returnTransientError = true;

// This service is attached to 'orderProcessorListener' and handles incoming orders.
service on orderProcessorListener {

    isolated remote function onMessage(anydata payload) returns error? {
        Order 'order = check jsondata:parseAsType(payload.toJson());
        log:printInfo("processing order", orderId = 'order.orderId);

        // Simulate a transient processing failure for specific order
        // For example, an external inventory service might be temporarily down for "OrderXYZ"
        lock {
            if returnTransientError && 'order.orderId == "OrderXYZ" {
                returnTransientError = false; // Prevent further transient errors for this order
                error err = error("Inventory service unavailable for OrderXYZ");
                log:printError("failed to process order", err, orderId = 'order.orderId);
                return err;
            }
        }

        // Simulate a consistent processing failure for "CriticalOrderABC" that always fails
        if 'order.orderId == "CriticalOrderABC" {
            error err = error("Invalid order data for CriticalOrderABC");
            log:printError("failed to process order", err, orderId = 'order.orderId);
            return err;
        }

        // Simulate successful processing
        log:printInfo("successfully processed order", orderId = 'order.orderId);
    }
}
