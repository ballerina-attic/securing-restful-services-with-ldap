// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import ballerina/http;
import ballerina/ldap;
import ballerina/log;
//import ballerinax/docker;
//import ballerinax/kubernetes;

// Configuration options to integrate Ballerina service
// with an LDAP server
ldap:LdapConnectionConfig ldapConnectionConfig = {
    // Unique name to identify the user store
    domainName: "ballerina.io",
    // Connection URL to the LDAP server
    connectionURL: "ldap://localhost:9389",
    // The username used to connect to the LDAP server
    connectionName: "uid=admin,ou=system",
    // Password for the ConnectionName user
    connectionPassword: "secret",
    // DN of the context or object under which
    // the user entries are stored in the LDAP server
    userSearchBase: "ou=Users,dc=ballerina,dc=io",
    // Object class used to construct user entries
    userEntryObjectClass: "identityPerson",
    // The attribute used for uniquely identifying a user entry
    userNameAttribute: "uid",
    // Filtering criteria used to search for a particular user entry
    userNameSearchFilter: "(&(objectClass=person)(uid=?))",
    // Filtering criteria for searching user entries in the LDAP server
    userNameListFilter: "(objectClass=person)",
    // DN of the context or object under which
    // the group entries are stored in the LDAP server
    groupSearchBase: ["ou=Groups,dc=ballerina,dc=io"],
    // Object class used to construct group entries
    groupEntryObjectClass: "groupOfNames",
    // The attribute used for uniquely identifying a group entry
    groupNameAttribute: "cn",
    // Filtering criteria used to search for a particular group entry
    groupNameSearchFilter: "(&(objectClass=groupOfNames)(cn=?))",
    // Filtering criteria for searching group entries in the LDAP server
    groupNameListFilter: "(objectClass=groupOfNames)",
    // Define the attribute that contains the distinguished names
    // (DN) of user objects that are in a group
    membershipAttribute: "member",
    // To indicate whether to cache the role list of a user
    userRolesCacheEnabled: true,
    // Define whether LDAP connection pooling is enabled
    connectionPoolingEnabled: false,
    // Timeout in making the initial LDAP connection
    ldapConnectionTimeout: 5000,
    // Read timeout for LDAP operations in milliseconds
    readTimeoutInMillis: 60000,
    // Retry the authentication request if a timeout happened
    retryAttempts: 3
};

ldap:InboundLdapAuthProvider ldapAuthProvider = new(ldapConnectionConfig, "ldap01");
http:BasicAuthHandler basicAuthHandler = new(ldapAuthProvider);

//@kubernetes:Ingress {
//    hostname:"ballerina.guides.io",
//    name:"ballerina-guides-secure-restful-service",
//    path:"/"
//}
//
//@kubernetes:Service {
//    serviceType:"NodePort",
//    name:"ballerina-guides-secure-restful-service"
//}
//
//@kubernetes:Deployment {
//    image:"ballerina.guides.io/secure_restful_service:v1.0",
//    name:"ballerina-guides-secure-restful-service"
//}

//@docker:Config {
//    registry:"ballerina.guides.io",
//    name:"secure_restful_service",
//    tag:"v1.0"
//}
//@docker:Expose{}
listener http:Listener httpListener = new(9090, {
    auth: { authHandlers: [basicAuthHandler] },
    secureSocket: {
        keyStore: {
            path: "${ballerina.home}/bre/security/ballerinaKeystore.p12",
            password: "ballerina"
        },
        trustStore: {
            path: "${ballerina.home}/bre/security/ballerinaTruststore.p12",
            password: "ballerina"
        }
    }
});

// Order management is done using an in memory map.
// Add some sample orders to 'orderMap' at startup.
map<map<json>> ordersMap = {};

// RESTful service.
@http:ServiceConfig {
    basePath: "/ordermgt",
    auth: {
        enabled: true
    }
}
service order_mgt on httpListener {

    // Resource that handles the HTTP POST requests that are directed
    // to the path '/order' to create a new Order.
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/order",
        auth: {
            scopes: ["add_order"]
        }
    }
    resource function addOrder(http:Caller caller, http:Request req) {
        var orderReq = req.getJsonPayload();
        if (orderReq is map<json>) {
            string orderId = orderReq.Order.ID.toString();

            // Get untainted value if `orderId` is a valid input
            orderId = <@untainted> orderId;

            ordersMap[orderId] = orderReq;

            // Create response message.
            json payload = { status: "Order Created.", orderId: orderId };
            http:Response response = new;
            response.setPayload(<@untainted> payload);

            // Set 201 Created status code in the response message.
            response.statusCode = http:STATUS_CREATED;
            // Set 'Location' header in the response message.
            // This can be used by the client to locate the newly added order.
            response.setHeader("Location", "http://localhost:9090/ordermgt/order/" + orderId);

            // Send response to the caller.
            var responseToCaller = caller->respond(response);
            if (responseToCaller is error) {
                log:printError("Error sending response", err = responseToCaller);
            }
        } else {
            var responseToCaller = caller->respond("Error in extracting json payload from request");
            if (responseToCaller is error) {
                log:printError("Error sending response", err = responseToCaller);
            }
        }
    }

    // Resource that handles the HTTP PUT requests that are directed
    // to the path '/orders' to update an existing Order.
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/order/{orderId}",
        auth: {
            scopes: ["update_order"]
        }
    }
    resource function updateOrder(http:Caller caller, http:Request req, string orderId) {
        var updatedOrder = req.getJsonPayload();
        http:Response response = new;

        if (updatedOrder is json) {
            // Get untainted value if `orderId` is a valid input
            string validOrderId = <@untainted> orderId;

            // Find the order that needs to be updated and retrieve it in JSON format.
            var existingOrder = ordersMap[validOrderId];
            if (existingOrder is map<map<json>>) {                
                existingOrder = <@untainted> existingOrder;
            }

            // Get untainted json value if it is a valid json
            updatedOrder = <@untainted> updatedOrder;

            // Updating existing order with the attributes of the updated order.
            if (existingOrder is map<map<json>>) {
                var name = updatedOrder.Order.Name;
                if (name is json) {
                    existingOrder["Order"]["Name"] = name;
                } 
                var description = updatedOrder.Order.Description;
                if (description is json) {
                   existingOrder["Order"]["Description"] =  description;
                }
                ordersMap[validOrderId] = existingOrder;
                // Set the JSON payload to the outgoing response message to the client.
                response.setPayload(existingOrder);
            } else {
                response.setPayload("Order : " + validOrderId + " cannot be found.");
            }

            // Send response to the caller.
            var responseToCaller = caller->respond(response);
            if (responseToCaller is error) {
                log:printError("Error sending response", err = responseToCaller);
            }
        } else {
            var responseToCaller = caller->respond("Error in extracting json payload from request");
            if (responseToCaller is error) {
                log:printError("Error sending response", err = responseToCaller);
            }
        }
    }

    // Resource that handles the HTTP DELETE requests, which are
    // directed to the path '/orders/<orderId>' to delete an existing Order.
    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/order/{orderId}",
        auth: {
            scopes: ["cancel_order"]
        }
    }
    resource function cancelOrder(http:Caller caller, http:Request req, string orderId) {
        // Get untainted string value if `orderId` is a valid input
        string validOrderId = <@untainted> orderId;

        // Remove the requested order from the map.
        var ordersMapAfterRemoving = ordersMap.remove(validOrderId);
        http:Response response = new;
        json payload = {};
        if (!ordersMap.hasKey(validOrderId)) {
            payload = { status: "Order : " + validOrderId + " removed." };
        } else {
            payload = { status: "Failed to remove the order : " + validOrderId };
        }

        // Set a generated payload with order status.
        response.setPayload(payload);

        // Send response to the caller.
        var responseToCaller = caller->respond(response);
        if (responseToCaller is error) {
            log:printError("Error sending response", err = responseToCaller);
        }
    }

    // Resource that handles the HTTP GET requests that are directed
    // to a specific order using path '/orders/<orderID>'
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/order/{orderId}",
        auth: {
            enabled: false
        }
    }
    resource function findOrder(http:Caller caller, http:Request req, string orderId) {
        // Get untainted string value if `orderId` is a valid input
        string validOrderId = <@untainted> orderId;

        // Find the requested order from the map and retrieve it in JSON format.
        http:Response response = new;
        json payload = {};
        if (ordersMap.hasKey(validOrderId)) {
            payload = ordersMap[validOrderId];
        } else {
            response.statusCode = http:STATUS_NOT_FOUND;
            payload = { status: "Order : " + validOrderId + " cannot be found." };
        }

        // Set the JSON payload in the outgoing response message.
        response.setPayload(payload);

        // Send response to the caller.
        var responseToCaller = caller->respond(response);
        if (responseToCaller is error) {
            log:printError("Error sending response", err = responseToCaller);
        }
    }
}

