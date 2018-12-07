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

import ballerina/test;
import ballerina/http;

http:Client clientEPUnauthenticated = new("https://localhost:9090/ordermgt");

http:Client clientEPCounter = new("https://localhost:9090/ordermgt", config = {
    auth: { scheme: http:BASIC_AUTH, username: "counter", password: "ballerina" }
});

http:Client clientEPAdmin = new("https://localhost:9090/ordermgt", config = {
    auth: { scheme: http:BASIC_AUTH, username: "admin", password: "ballerina" }
});

// Unauthenticated invocations

@test:Config
// Function to test POST resource 'addOrder' with no authentication.
function testResourceAddOrderUnauthenticated() {
    // Initialize the empty http request.
    http:Request request = new;
    // Construct the request payload.
    json payload = { "Order": { "ID": "100500", "Name": "XYZ", "Description": "Sample order." } };
    request.setPayload(payload);
    // Send 'POST' request and obtain the response.
    var response = clientEPUnauthenticated->post("/order", request);
    if (response is http:Response) {
        // Expected response code is 401.
        test:assertEquals(response.statusCode, http:UNAUTHORIZED_401,
            msg = "addOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getTextPayload();
        if (resPayload is string) {
            test:assertEquals(resPayload, "Authentication failure", msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the text payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}


@test:Config {
    dependsOn: ["testResourceAddOrderUnauthenticated"]
}
// Function to test PUT resource 'updateOrder' with no authentication.
function testResourceUpdateOrderUnauthenticated() {
    // Initialize empty http requests and responses.
    http:Request request = new;
    // Construct the request payload.
    json payload = { "Order": { "Name": "XYZ", "Description": "Updated order." } };
    request.setPayload(payload);
    // Send 'PUT' request and obtain the response.
    var response = clientEPUnauthenticated->put("/order/100500", request);
    if (response is http:Response) {
        // Expected response code is 401.
        test:assertEquals(response.statusCode, http:UNAUTHORIZED_401,
            msg = "updateOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getTextPayload();
        if (resPayload is string) {
            test:assertEquals(resPayload, "Authentication failure", msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the text payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

@test:Config {
    dependsOn: ["testResourceUpdateOrderUnauthenticated"]
}
// Function to test GET resource 'findOrder' with no authentication.
function testResourceFindOrderUnauthenticated() {
    // Initialize empty http requests and responses.
    http:Request request = new;
    // Send 'GET' request and obtain the response.
    var response = clientEPUnauthenticated->get("/order/100500", message = request);
    if (response is http:Response) {
        // Expected response code is 500.
        test:assertEquals(response.statusCode, http:NOT_FOUND_404,
            msg = "findOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getJsonPayload();
        if (resPayload is json) {
            test:assertEquals(resPayload.toString(), "{\"status\":\"Order : 100500 cannot be found.\"}",
                msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the json payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

@test:Config {
    dependsOn: ["testResourceFindOrderUnauthenticated"]
}
// Function to test DELETE resource 'cancelOrder' with no authentication.
function testResourceCancelOrderUnauthenticated() {
    // Initialize empty http requests and responses.
    http:Request request = new;
    // Send 'DELETE' request and obtain the response.
    var response = clientEPUnauthenticated->delete("/order/100500", request);
    if (response is http:Response) {
        // Expected response code is 401.
        test:assertEquals(response.statusCode, http:UNAUTHORIZED_401,
            msg = "cancelOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getTextPayload();
        if (resPayload is string) {
            test:assertEquals(resPayload, "Authentication failure", msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the text payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}


// Counter user invocations

@test:Config
// Function to test POST resource 'addOrder' with counter user.
function testResourceAddOrderWithCounterUser() {
    // Initialize the empty http request.
    http:Request request = new;
    // Construct the request payload.
    json payload = { "Order": { "ID": "100501", "Name": "XYZ", "Description": "Sample order." } };
    request.setPayload(payload);
    // Send 'POST' request and obtain the response.
    var response = clientEPCounter->post("/order", request);
    if (response is http:Response) {
        // Expected response code is 201.
        test:assertEquals(response.statusCode, http:CREATED_201,
            msg = "addOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getJsonPayload();
        if (resPayload is json) {
            test:assertEquals(resPayload.toString(),
                "{\"status\":\"Order Created.\", \"orderId\":\"100501\"}", msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the json payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

@test:Config {
    dependsOn: ["testResourceAddOrderWithCounterUser"]
}
// Function to test PUT resource 'updateOrder' with counter user.
function testResourceUpdateOrderWithCounterUser() {
    // Initialize empty http requests and responses.
    http:Request request = new;
    // Construct the request payload.
    json payload = { "Order": { "Name": "XYZ", "Description": "Updated order." } };
    request.setPayload(payload);
    // Send 'PUT' request and obtain the response.
    var response = clientEPCounter->put("/order/100501", request);
    if (response is http:Response) {
        // Expected response code is 403.
        test:assertEquals(response.statusCode, http:FORBIDDEN_403,
            msg = "updateOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getTextPayload();
        if (resPayload is string) {
            test:assertEquals(resPayload, "Authorization failure", msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the text payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

@test:Config {
    dependsOn: ["testResourceUpdateOrderWithCounterUser"]
}
// Function to test GET resource 'findOrder' with counter user.
function testResourceFindOrderWithCounterUser() {
    // Initialize empty http requests and responses.
    http:Request request = new;
    // Send 'GET' request and obtain the response.
    var response = clientEPCounter->get("/order/100501", message = request);
    if (response is http:Response) {
        // Expected response code is 200.
        test:assertEquals(response.statusCode, http:OK_200,
            msg = "findOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getJsonPayload();
        if (resPayload is json) {
            test:assertEquals(resPayload.toString(),
                "{\"Order\":{\"ID\":\"100501\", \"Name\":\"XYZ\", \"Description\":\"Sample order.\"}}",
                msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the json payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

@test:Config {
    dependsOn: ["testResourceFindOrderWithCounterUser"]
}
// Function to test DELETE resource 'cancelOrder' with counter user.
function testResourceCancelOrderWithCounterUser() {
    // Initialize empty http requests and responses.
    http:Request request = new;
    // Send 'DELETE' request and obtain the response.
    var response = clientEPCounter->delete("/order/100501", request);
    if (response is http:Response) {
        // Expected response code is 403.
        test:assertEquals(response.statusCode, http:FORBIDDEN_403,
            msg = "cancelOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getTextPayload();
        if (resPayload is string) {
            test:assertEquals(resPayload, "Authorization failure", msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the text payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

// Admin user invocations

@test:Config
// Function to test POST resource 'addOrder' with admin user.
function testResourceAddOrderWithAdminUser() {
    // Initialize the empty http request.
    http:Request request = new;
    // Construct the request payload.
    json payload = { "Order": { "ID": "100502", "Name": "XYZ", "Description": "Sample order." } };
    request.setPayload(payload);
    // Send 'POST' request and obtain the response.
    var response = clientEPAdmin->post("/order", request);
    if (response is http:Response) {
        // Expected response code is 201.
        test:assertEquals(response.statusCode, http:CREATED_201,
                            msg = "addOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getJsonPayload();
        if (resPayload is json) {
            test:assertEquals(resPayload.toString(),
                "{\"status\":\"Order Created.\", \"orderId\":\"100502\"}", msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the json payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

@test:Config {
    dependsOn: ["testResourceAddOrderWithAdminUser"]
}
// Function to test PUT resource 'updateOrder' with admin user.
function testResourceUpdateOrderWithAdminUser() {
    // Initialize empty http requests and responses.
    http:Request request = new;
    // Construct the request payload.
    json payload = { "Order": { "Name": "XYZ", "Description": "Updated order." } };
    request.setJsonPayload(payload);
    // Send 'PUT' request and obtain the response.
    var response = clientEPAdmin->put("/order/100502", request);
    if (response is http:Response) {
        // Expected response code is 200.
        test:assertEquals(response.statusCode, http:OK_200,
            msg = "updateOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getJsonPayload();
        if (resPayload is json) {
            test:assertEquals(resPayload.toString(),
                "{\"Order\":{\"ID\":\"100502\", \"Name\":\"XYZ\", \"Description\":\"Updated order.\"}}",
                msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the json payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

@test:Config {
    dependsOn: ["testResourceUpdateOrderWithAdminUser"]
}
// Function to test GET resource 'findOrder' with admin user.
function testResourceFindOrderWithAdminUser() {
    // Initialize empty http requests and responses.
    http:Request request;
    // Send 'GET' request and obtain the response.
    var response = clientEPAdmin->get("/order/100502", message = request);
    if (response is http:Response) {
        // Expected response code is 200.
        test:assertEquals(response.statusCode, http:OK_200,
            msg = "findOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getJsonPayload();
        if (resPayload is json) {
            test:assertEquals(resPayload.toString(),
                "{\"Order\":{\"ID\":\"100502\", \"Name\":\"XYZ\", \"Description\":\"Updated order.\"}}",
                msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the json payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}

@test:Config {
    dependsOn: ["testResourceFindOrderWithAdminUser"]
}
// Function to test DELETE resource 'cancelOrder' with admin user.
function testResourceCancelOrderWithAdminUser() {
    // Initialize empty http requests and responses.
    http:Request request = new;
    // Send 'DELETE' request and obtain the response.
    var response = clientEPAdmin->delete("/order/100502", request);
    if (response is http:Response) {
        // Expected response code is 200.
        test:assertEquals(response.statusCode, http:OK_200,
            msg = "cancelOrder resource did not respond with expected response code!");
        // Check whether the response is as expected.
        var resPayload = response.getJsonPayload();
        if (resPayload is json) {
            test:assertEquals(resPayload.toString(), "{\"status\":\"Order : 100502 removed.\"}",
                msg = "Response mismatch!");
        } else if (resPayload is error) {
            test:assertFail(msg = "Failed to parse the json payload");
        }
    } else if (response is error) {
        test:assertFail(msg = "Failed to call the endpoint");
    }
}
