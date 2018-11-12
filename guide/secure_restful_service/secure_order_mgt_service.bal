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

import ballerina/auth;
import ballerina/http;
//import ballerinax/docker;
//import ballerinax/kubernetes;

@final string regexInt = "\\d+";
@final string regexJson = "[a-zA-Z0-9.,{}:\" ]*";

// Configuration options to integrate Ballerina service
// with an LDAP server
auth:LdapAuthProviderConfig ldapAuthProviderConfig = {
    // Unique name to identify the user store
    domainName: "ballerina.io",
    // Connection URL to the LDAP server
    connectionURL: "ldap://172.17.0.2:9389",
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
    // The value of this property is the read timeout in
    // milliseconds for LDAP operations
    readTimeout: 60000,
    // Retry the authentication request if a timeout happened
    retryAttempts: 3
};

http:AuthProvider basicAuthProvider = {
    id: "basic01",
    scheme: http:AUTHN_SCHEME_BASIC,
    authStoreProvider: http:AUTH_PROVIDER_LDAP,
    authStoreProviderConfig: ldapAuthProviderConfig
};

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
endpoint http:Listener listener {
    port: 9090,
    secureSocket: {
        keyStore: {
            path: "${ballerina.home}/bre/security/ballerinaKeystore.p12",
            password: "ballerina"
        },
        trustStore: {
            path: "${ballerina.home}/bre/security/ballerinaTruststore.p12",
            password: "ballerina"
        }
    },
    authProviders: [basicAuthProvider]
};

// Order management is done using an in memory map.
// Add some sample orders to 'orderMap' at startup.
map<json> ordersMap;

@Description { value: "RESTful service." }
@http:ServiceConfig {
    basePath: "/ordermgt",
    authConfig: {
        authentication: { enabled: true }
    }
}
service<http:Service> order_mgt bind listener {

    @Description { value: "Resource that handles the HTTP POST requests that are directed
     to the path '/order' to create a new Order." }
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/order",
        authConfig: {
            scopes: ["add_order"]
        }
    }
    addOrder(endpoint client, http:Request req) {
        json orderReq = check req.getJsonPayload();
        string orderId = orderReq.Order.ID.toString();

        // Get untainted value if `orderId` is a valid input
        orderId = getUntaintedStringIfValid(orderId);

        ordersMap[orderId] = orderReq;

        // Create response message.
        json payload = { status: "Order Created.", orderId: orderId };
        http:Response response;
        response.setPayload(payload);

        // Set 201 Created status code in the response message.
        response.statusCode = http:CREATED_201;
        // Set 'Location' header in the response message.
        // This can be used by the client to locate the newly added order.
        response.setHeader("Location", "http://localhost:9090/ordermgt/order/" + orderId);

        // Send response to the client.
        _ = client->respond(response);
    }

    @Description { value: "Resource that handles the HTTP PUT requests that are directed
    to the path '/orders' to update an existing Order." }
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/order/{orderId}",
        authConfig: {
            scopes: ["update_order"]
        }
    }
    updateOrder(endpoint client, http:Request req, string orderId) {
        json updatedOrder = check req.getJsonPayload();

        // Get untainted value if `orderId` is a valid input
        orderId = getUntaintedStringIfValid(orderId);

        // Find the order that needs to be updated and retrieve it in JSON format.
        json existingOrder = ordersMap[orderId];

        // Get untainted json value if it is a valid json
        existingOrder = getUntaintedJsonIfValid(existingOrder);
        updatedOrder = getUntaintedJsonIfValid(updatedOrder);

        // Updating existing order with the attributes of the updated order.
        if (existingOrder != null) {

            existingOrder.Order.Name = updatedOrder.Order.Name;
            existingOrder.Order.Description = updatedOrder.Order.Description;
            ordersMap[orderId] = existingOrder;
        } else {
            existingOrder = "Order : " + orderId + " cannot be found.";
        }

        http:Response response;
        // Set the JSON payload to the outgoing response message to the client.
        response.setPayload(existingOrder);
        // Send response to the client.
        _ = client->respond(response);
    }

    @Description { value: "Resource that handles the HTTP DELETE requests, which are
    directed to the path '/orders/<orderId>' to delete an existing Order." }
    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/order/{orderId}",
        authConfig: {
            scopes: ["cancel_order"]
        }
    }
    cancelOrder(endpoint client, http:Request req, string orderId) {
        // Get untainted string value if `orderId` is a valid input
        orderId = getUntaintedStringIfValid(orderId);

        // Remove the requested order from the map.
        _ = ordersMap.remove(orderId);

        http:Response response;
        json payload = { status: "Order : " + orderId + " removed." };
        // Set a generated payload with order status.
        response.setPayload(payload);

        // Send response to the client.
        _ = client->respond(response);
    }

    @Description { value: "Resource that handles the HTTP GET requests that are directed
    to a specific order using path '/orders/<orderID>'" }
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/order/{orderId}",
        authConfig: {
            authentication: { enabled: false }
        }
    }
    findOrder(endpoint client, http:Request req, string orderId) {
        // Get untainted string value if `orderId` is a valid input
        orderId = getUntaintedStringIfValid(orderId);

        // Find the requested order from the map and retrieve it in JSON format.
        http:Response response;
        json payload;
        if (ordersMap.hasKey(orderId)) {
            payload = ordersMap[orderId];
        } else {
            response.statusCode = http:NOT_FOUND_404;
            payload = { status: "Order : " + orderId + " cannot be found." };
        }

        // Set the JSON payload in the outgoing response message.
        response.setPayload(payload);

        // Send response to the client.
        _ = client->respond(response);
    }
}

function getUntaintedStringIfValid(string input) returns @untainted string {
    boolean isValid = check input.matches(regexInt);
    if (isValid) {
        return input;
    } else {
        error err = { message: "Validation error: Input '" + input + "' should be valid." };
        throw err;
    }
}

function getUntaintedJsonIfValid(json input) returns @untainted json {
    string inputStr = input.toString();
    boolean isValid = check inputStr.matches(regexJson);
    if (isValid) {
        return input;
    } else {
        error err = { message: "Validation error: Input payload '" + inputStr + "' should be valid." };
        throw err;
    }
}
