[![Build Status](https://travis-ci.org/ballerina-guides/securing-restful-services-with-ldap.svg?branch=master)](https://travis-ci.org/ballerina-guides/securing-restful-services-with-basic-auth)

# Securing RESTful Services with LDAP

In this guide you will learn about integrating external LDAP to a service that enforces authentication and 
authorization checks using Ballerina.

The following are the sections available in this guide.

- [What you'll build](#what-youll-build)
- [Prerequisites](#prerequisites)
- [Developing the service](#developing-the-service)
- [Testing](#testing)
- [Deployment](#deployment)
- [Observability](#observability)

## What you’ll build
To understand how you can secure a RESTful web service using Ballerina, let’s secure the web service you created in
the [RESTful Service guide](https://ballerina.io/learn/by-guide/restful-service/).

The following figure illustrates all the functionalities of the OrderMgt RESTful web service, that should be secured.

![RESTful Service](images/restful-service.svg "RESTful Service")

- **Create Order** : Order creation should be allowed for all the users. Authentication or authorization should not be enforced for this function.
- **Retrieve Order** : Retrieval of the order details should only be allowed for authenticated users.
- **Update Order** : Updating order details should only be allowed for "admin" users.
- **Delete Order** : Deletion of the order should only be allowed for "admin" users.

## Prerequisites

- [Ballerina Distribution](https://ballerina.io/learn/getting-started/)
- A Text Editor or an IDE 
> **Tip**: For a better development experience, install one of the following Ballerina IDE plugins: [VSCode](https://marketplace.visualstudio.com/items?itemName=ballerina.ballerina), [IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina)
- [Docker](https://docs.docker.com/engine/installation/)
- To provide the required LDAP user store for this guide, we have created a Docker image with an embedded Apache DS, which contains the user details that should be used in authentication and authorization. We will use the following LDAP schema, which creates two users. The 'counter' user only has 'add_order' scope, whereas the 'admin' user has 'add_order', 'update_order', and 'cancel_order' scopes. Here, scopes are equivalent to LDAP groups. Follow the instructions below to setup the LDAP server necessary for the guide.

##### LDAP schema
```yaml
version: 1

dn: dc=ballerina,dc=io
objectClass: extensibleObject
objectClass: domain
objectClass: top
dc: ballerina

dn: ou=Users,dc=ballerina,dc=io
objectClass: organizationalUnit
objectClass: top
ou: Users

dn: ou=Groups,dc=ballerina,dc=io
objectClass: organizationalUnit
objectClass: top
ou: Groups

dn: uid=admin,ou=Users,dc=ballerina,dc=io
objectClass: organizationalPerson
objectClass: person
objectClass: extensibleObject
objectClass: uidObject
objectClass: inetOrgPerson
objectClass: top
cn: Test User
givenName: admin
sn: User
uid: admin
mail: admin@ballerina.io
ou: Users
userpassword: ballerina

dn: uid=counter,ou=Users,dc=ballerina,dc=io
objectClass: organizationalPerson
objectClass: person
objectClass: extensibleObject
objectClass: uidObject
objectClass: inetOrgPerson
objectClass: top
cn: Test User
givenName: counter
sn: User
uid: counter
mail: counter@ballerina.io
ou: Users
userpassword: ballerina

dn: cn=add_order,ou=Groups,dc=ballerina,dc=io
objectClass: groupOfNames
objectClass: top
cn: add_order
member: uid=counter,ou=Users,dc=ballerina,dc=io
member: uid=admin,ou=Users,dc=ballerina,dc=io

dn: cn=update_order,ou=Groups,dc=ballerina,dc=io
objectClass: groupOfNames
objectClass: top
cn: update_order
member: uid=admin,ou=Users,dc=ballerina,dc=io

dn: cn=cancel_order,ou=Groups,dc=ballerina,dc=io
objectClass: groupOfNames
objectClass: top
cn: cancel_order
member: uid=admin,ou=Users,dc=ballerina,dc=io
```
- Execute the following command to pull the Docker image from the Docker hub.
```bash
docker pull vijithaekanayake/embedded_ldap_server:1.0.0
```
- After pulling the Docker image, execute the following command to start the LDAP server.
```bash
docker run -d -p 9389:9389 vijithaekanayake/embedded_ldap_server:1.0.0
```

### Optional requirements
- Ballerina IDE plugins ([IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina), [VSCode](https://marketplace.visualstudio.com/items?itemName=WSO2.Ballerina), [Atom](https://atom.io/packages/language-ballerina))

## Developing the service

- Let's get started with a Ballerina service; 'OrderMgtService', which is the RESTful service that serves the order management request. We will look at securing multiple resources exposed by OrderMgtService to match with the different security requirements.

- Although the language allows you to have any package structure, use the following package structure for this 
project to follow this guide. The root directory is denoted by `SAMPLE_ROOT` in the context of this README.

```
secure-restful-service
  └── src
      └── secure_restful_service
          ├── secure_order_mgt_service.bal
          └── tests
              └── secure_order_mgt_service_test.bal
```

- Open the terminal and create a ballerina project named 'secure-restful-service'.

```bash
   $ ballerina new secure-restful-service
```

 - The above command initializes the project with the Ballerina.toml file, src folder, and a tests folder.
 
 - Once the project is initialized, a module can be created inside the project using the ballerina create command. 
 ```bash
   $ ballerina create secure_restful_service
 ```
 
 - `LdapConnectionConfig` record provides the required set of fields for the LDAP integration. Given configurations
  are aligned with the provided embedded LDAP server to demonstrate the scenario.

- Add the following content to your Ballerina service, which is the service created in "RESTful Service" Ballerina by Guide, but with authentication and authorization related annotation attributes added to the service and resource configuration. `authentication` is enabled in `auth` attribute of `ServiceConfig`. Therefore, authentication will be enforced on all the resources of the service. However, since we have overridden the `authentication` enabled status to 'false' for `findOrder` functionality, authentication will not be enforced for `findOrder`.

##### secure_order_mgt_service.bal
```ballerina
import ballerina/http;
import ballerina/ldap;
import ballerina/log;

// Configuration options to integrate Ballerina service
// with an LDAP server.
ldap:LdapConnectionConfig ldapConnectionConfig = {
    // Unique name to identify the user store.
    domainName: "ballerina.io",
    // Connection URL to the LDAP server.
    connectionURL: "ldap://localhost:9389",
    // The username used to connect to the LDAP server.
    connectionName: "uid=admin,ou=system",
    // Password for the ConnectionName user.
    connectionPassword: "secret",
    // DN of the context or object under which
    // the user entries are stored in the LDAP server.
    userSearchBase: "ou=Users,dc=ballerina,dc=io",
    // Object class used to construct user entries.
    userEntryObjectClass: "identityPerson",
    // The attribute used for uniquely identifying a user entry.
    userNameAttribute: "uid",
    // Filtering criteria used to search for a particular user entry.
    userNameSearchFilter: "(&(objectClass=person)(uid=?))",
    // Filtering criteria for searching user entries in the LDAP server.
    userNameListFilter: "(objectClass=person)",
    // DN of the context or object under which
    // the group entries are stored in the LDAP server.
    groupSearchBase: ["ou=Groups,dc=ballerina,dc=io"],
    // Object class used to construct group entries.
    groupEntryObjectClass: "groupOfNames",
    // The attribute used for uniquely identifying a group entry.
    groupNameAttribute: "cn",
    // Filtering criteria used to search for a particular group entry.
    groupNameSearchFilter: "(&(objectClass=groupOfNames)(cn=?))",
    // Filtering criteria for searching group entries in the LDAP server.
    groupNameListFilter: "(objectClass=groupOfNames)",
    // Define the attribute that contains the distinguished names
    // (DN) of user objects that are in a group.
    membershipAttribute: "member",
    // To indicate whether to cache the role list of a user.
    userRolesCacheEnabled: true,
    // Define whether LDAP connection pooling is enabled.
    connectionPoolingEnabled: false,
    // Timeout in making the initial LDAP connection.
    ldapConnectionTimeout: 5000,
    // Read timeout for LDAP operations in milliseconds.
    readTimeoutInMillis: 60000,
    // Retry the authentication request if a timeout happened.
    retryAttempts: 3
};

ldap:InboundLdapAuthProvider ldapAuthProvider = new(ldapConnectionConfig, "ldap01");
http:BasicAuthHandler basicAuthHandler = new(ldapAuthProvider);

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
            response.statusCode = http:STATUS_ACCEPTED;
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

```
- Ballerina uses `scope` as the way of expressing authorization. Multiple scopes can be assigned to a user, and scopes can then be validated while enforcing authorization. In order to express that certain service or resources require a scope, we have used the `scopes` annotation attribute. According to the `auth` of the service, in order to invoke `addOrder` function, the user should have 'add_order' scope, whereas to invoke `updateOrder` and `cancelOrder` user should have 'update_order' and 'cancel_order' scopes respectively.

## Testing

### Invoking the RESTful service

You can run the RESTful service that you developed above in your local environment. You need to have the Ballerina installation in your local machine and simply point to the <ballerina>/bin/ballerina binary to execute all the following steps.  

1. As the first step you can build a Ballerina executable JAR of the service that we developed above, 
using the following command. It points to the directory in which the service we developed above located and it will create an executable binary out of that. Navigate to the `secure-restful-service/` folder and run the following command.

```bash
$ ballerina build secure_restful_service
```

2. Once the secure_order_mgt_service_executable.jar is created inside the target folder, you can run that with the following command.

```bash
$ ballerina run target/bin/secure_restful_service-executable.jar
```

3. The successful execution of the service should show us the following output.

```bash
$ ballerina run target/bin/secure-restful-service-executable.jar

ballerina: started HTTP/WS endpoint 0.0.0.0:9090
```

4. You can test authentication and authorization checks being enforced on different functions of the OrderMgt RESTFul service by sending HTTP request. For example, we have used the curl commands to test each operation of OrderMgtService as follows.

**Create Order - Without authentication**

```
curl -kv -X POST -d \
'{ "Order": { "ID": "100500", "Name": "XYZ", "Description": "Sample order."}}' \
"https://localhost:9090/ordermgt/order" -H "Content-Type:application/json"

Output :  
< HTTP/1.1 401 Unauthorized
< content-type: text/plain
< content-length: 38
< server: ballerina/0.970.0-beta0
< date: Tue, 24 Jul 2018 15:32:39 +0530

Authentication failure
```

**Create Order - Authenticating as 'counter' user**

```
curl -kv -X POST -u counter:ballerina -d \
'{ "Order": { "ID": "100500", "Name": "XYZ", "Description": "Sample order."}}' \
"https://localhost:9090/ordermgt/order" -H "Content-Type:application/json"

Output :  
< HTTP/1.1 201 Created
< Content-Type: application/json
< Location: http://localhost:9090/ordermgt/order/100500
< content-length: 46
< server: ballerina/0.980.2-SNAPSHOT
< date: Tue, 24 Jul 2018 15:33:06 +0530

{"status":"Order Created.","orderId":"100500"}
```

**Retrieve Order - Without authentication**

Authentication is disabled for `findOrder` operation. Therefore, the following request will succeed.

```
curl -k "https://localhost:9090/ordermgt/order/100500"

Output :
{"Order":{"ID":"100500","Name":"XYZ","Description":"Sample order."}}
```

**Update Order - Without authentication**
```
curl -k -X PUT -d '{ "Order": {"Name": "XYZ", "Description": "Updated order."}}' \
"https://localhost:9090/ordermgt/order/100500" -H "Content-Type:application/json"

Output:
Authentication failure
```

**Update Order - Authenticating as 'counter' user**

Authorization check for `updateOrder` operation requires the 'update_order' scope. The 'counter' user only has 'add_order' scope. Therefore, the following request will fail.

```
curl -k -X PUT -u counter:ballerina -d '{ "Order": {"Name": "XYZ", "Description": "Updated order."}}' \
"https://localhost:9090/ordermgt/order/100500" -H "Content-Type:application/json"

Output:
Authorization failure
```

**Update Order - Authenticating as 'admin' user**
```
curl -k -X PUT -u admin:ballerina -d '{ "Order": {"Name": "XYZ", "Description": "Updated order."}}' \
"https://localhost:9090/ordermgt/order/100500" -H "Content-Type:application/json"

Output:
{"Order":{"ID":"100500","Name":"XYZ","Description":"Updated order."}}
```

**Cancel Order - Authenticating as 'admin' user**
```
curl -k -u admin:ballerina -X DELETE "https://localhost:9090/ordermgt/order/100500"

Output:
"Order : 100500 removed."
```

### Writing unit tests

In Ballerina, the unit test cases should be in the same package inside a folder named as 'tests'. The naming convention should be as follows,

* Test functions should contain test prefix.
  * e.g.: testResourceAddOrder()

This guide contains unit test cases for each resource available in the 'order_mgt_service.bal'.

>Note: Make sure that embedded LDAP server is up and running prior to running the unit tests.

To run the unit tests, navigate to the `secure-restful-service` directory and run the following command.
```bash
   $ ballerina test
```

To check the implementation of the test file, refer to the [secure_order_mgt_service_test.bal](https://github.com/ballerina-guides/securing-restful-services-with-basic-auth/blob/master/guide/secure_restful_service/tests/secure_order_mgt_service_test.bal).

## Deployment

Once you are done with the development, you can deploy the service using any of the methods that we listed below.

### Deploying locally
You can deploy the RESTful service that you developed above, in your local environment. You can use the Ballerina executable archive (.jar) that we created above and run it in your local environment as follows.

```
$ ballerina run target/bin/secure_restful_service_executable.jar
```

### Deploying on Docker

You can run the service that we developed above as a Docker container. As Ballerina platform offers native support for running Ballerina programs on
containers, you just need to put the corresponding Docker annotations on your service code.

- In our OrderMgtService, we need to import `import ballerinax/docker;` and use the annotation `@docker:Config` as shown below to enable Docker image generation during the build time.

- Execute the `docker ps` command in the terminal and take the corresponding Docker process id for the LDAP server.
- Execute execute `docker inspect <PROCESS_ID>` and take IP address of the LDAP server container.

```
   $ docker ps
```

```
   $ docker inspect <PROCESS_ID>
```

- Then update the LDAP `connectionURL` of `LdapAuthProviderConfig` with the LDAP server container IP address.

##### secure_order_mgt_service.bal
```ballerina
package secure_restful_service;

import ballerina/auth;
import ballerina/http;
import ballerina/log;
import ballerinax/docker;

// Configuration options to integrate Ballerina service
// with an LDAP server.
ldap:LdapConnectionConfig ldapConnectionConfig = {
    // Unique name to identify the user store.
    domainName: "ballerina.io",
    // Connection URL to the LDAP server.
    connectionURL: "ldap://<IP_ADDRESS_OF_LDAP_SERVER_CONTAINER>:9389",
    // The username used to connect to the LDAP server.
    connectionName: "uid=admin,ou=system",
    // Password for the ConnectionName user.
    connectionPassword: "secret",
    // DN of the context or object under which
    // the user entries are stored in the LDAP server.
    userSearchBase: "ou=Users,dc=ballerina,dc=io",
    // Object class used to construct user entries.
    userEntryObjectClass: "identityPerson",
    // The attribute used for uniquely identifying a user entry.
    userNameAttribute: "uid",
    // Filtering criteria used to search for a particular user entry.
    userNameSearchFilter: "(&(objectClass=person)(uid=?))",
    // Filtering criteria for searching user entries in the LDAP server.
    userNameListFilter: "(objectClass=person)",
    // DN of the context or object under which
    // the group entries are stored in the LDAP server.
    groupSearchBase: ["ou=Groups,dc=ballerina,dc=io"],
    // Object class used to construct group entries.
    groupEntryObjectClass: "groupOfNames",
    // The attribute used for uniquely identifying a group entry.
    groupNameAttribute: "cn",
    // Filtering criteria used to search for a particular group entry.
    groupNameSearchFilter: "(&(objectClass=groupOfNames)(cn=?))",
    // Filtering criteria for searching group entries in the LDAP server.
    groupNameListFilter: "(objectClass=groupOfNames)",
    // Define the attribute that contains the distinguished names
    // (DN) of user objects that are in a group.
    membershipAttribute: "member",
    // To indicate whether to cache the role list of a user.
    userRolesCacheEnabled: true,
    // Define whether LDAP connection pooling is enabled.
    connectionPoolingEnabled: false,
    // Timeout in making the initial LDAP connection.
    ldapConnectionTimeout: 5000,
    // Read timeout for LDAP operations in milliseconds.
    readTimeoutInMillis: 60000,
    // Retry the authentication request if a timeout happened.
    retryAttempts: 3
};

ldap:InboundLdapAuthProvider ldapAuthProvider = new(ldapConnectionConfig, "ldap01");
http:BasicAuthHandler basicAuthHandler = new(ldapAuthProvider);

@docker:Config {
    registry:"ballerina.guides.io",
    name:"secure_restful_service",
    tag:"v1.0"
}
@docker:Expose{}
listener http:Listener httpListener = new(9090, config = {
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
    auth: { authHandlers: [basicAuthHandler] }
});

// Order management is done using an in memory map.
// Add some sample orders to 'orderMap' at startup.
map<json> ordersMap = {};

// RESTful service.
@http:ServiceConfig {
    basePath: "/ordermgt",
    authConfig: {
        authentication: { enabled: true }
    }
}
service order_mgt on httpListener {
```

- Now you can build a Ballerina executable archive (.jar) of the service that we developed above, using the following command. It points to the service file that we developed above and it will create an executable binary out of that.
This will also create the corresponding Docker image using the Docker annotations that you have configured above.
Navigate to the `<SAMPLE_ROOT>/` folder and run the following command.

```
   $ ballerina build secure_restful_service --skiptests

   Run following command to start docker container:
   docker run -d -p 9090:9090 ballerina.guides.io/secure_restful_service:v1.0
```

- Once you successfully build the Docker image, you can run it with the `docker run` command that is shown in the previous step.

```   
   docker run -d -p 9090:9090 ballerina.guides.io/secure_restful_service:v1.0
```

Here we run the Docker image with flag`` -p <host_port>:<container_port>`` so that we  use  the host port 9090 and the container port 9090. Therefore you can access the service through the host port.
- Verify Docker container is running with the use of `` $ docker ps``. The status of the Docker container should be shown as 'Up'.
- You can access the service using the same curl commands that we've used above.

```
   curl -kv -X POST -u counter:ballerina -d '{ "Order": { "ID": "100500", "Name": "XYZ", "Description": "Sample order
   ."}}' \
   "https://localhost:9090/ordermgt/order" -H "Content-Type:application/json"
```

### Deploying on Kubernetes

- You can run the service that we developed above, on Kubernetes. The Ballerina language offers native support for running a Ballerina programs on Kubernetes,
with the use of Kubernetes annotations that you can include as part of your service code. Also, it will take care of the creation of the Docker images.
So you don't need to explicitly create Docker images prior to deploying it on Kubernetes.

- We need to import `` import ballerinax/kubernetes; `` and use `` @kubernetes `` annotations as shown below to enable kubernetes deployment for the service we developed above.

> NOTE: Linux users can use Minikube to try this out locally.

- Make sure to update the LDAP connectionURL of LdapAuthProviderConfig with the LDAP server container IP address

##### order_mgt_service.bal

```ballerina
package secure_restful_service;

import ballerina/auth;
import ballerina/http;
import ballerina/log;
import ballerinax/kubernetes;

// Configuration options to integrate Ballerina service
// with an LDAP server.
ldap:LdapConnectionConfig ldapConnectionConfig = {
    // Unique name to identify the user store.
    domainName: "ballerina.io",
    // Connection URL to the LDAP server.
    connectionURL: "ldap://<IP_ADDRESS_OF_LDAP_SERVER_CONTAINER>:9389",
    // The username used to connect to the LDAP server.
    connectionName: "uid=admin,ou=system",
    // Password for the ConnectionName user.
    connectionPassword: "secret",
    // DN of the context or object under which
    // the user entries are stored in the LDAP server.
    userSearchBase: "ou=Users,dc=ballerina,dc=io",
    // Object class used to construct user entries.
    userEntryObjectClass: "identityPerson",
    // The attribute used for uniquely identifying a user entry.
    userNameAttribute: "uid",
    // Filtering criteria used to search for a particular user entry.
    userNameSearchFilter: "(&(objectClass=person)(uid=?))",
    // Filtering criteria for searching user entries in the LDAP server.
    userNameListFilter: "(objectClass=person)",
    // DN of the context or object under which
    // the group entries are stored in the LDAP server.
    groupSearchBase: ["ou=Groups,dc=ballerina,dc=io"],
    // Object class used to construct group entries.
    groupEntryObjectClass: "groupOfNames",
    // The attribute used for uniquely identifying a group entry.
    groupNameAttribute: "cn",
    // Filtering criteria used to search for a particular group entry.
    groupNameSearchFilter: "(&(objectClass=groupOfNames)(cn=?))",
    // Filtering criteria for searching group entries in the LDAP server.
    groupNameListFilter: "(objectClass=groupOfNames)",
    // Define the attribute that contains the distinguished names
    // (DN) of user objects that are in a group.
    membershipAttribute: "member",
    // To indicate whether to cache the role list of a user.
    userRolesCacheEnabled: true,
    // Define whether LDAP connection pooling is enabled.
    connectionPoolingEnabled: false,
    // Timeout in making the initial LDAP connection.
    ldapConnectionTimeout: 5000,
    // Read timeout for LDAP operations in milliseconds.
    readTimeoutInMillis: 60000,
    // Retry the authentication request if a timeout happened.
    retryAttempts: 3
};

ldap:InboundLdapAuthProvider ldapAuthProvider = new(ldapConnectionConfig, "ldap01");
http:BasicAuthHandler basicAuthHandler = new(ldapAuthProvider);

@kubernetes:Ingress {
    hostname:"ballerina.guides.io",
    name:"ballerina-guides-secure-restful-service",
    path:"/"
}

@kubernetes:Service {
    serviceType:"NodePort",
    name:"ballerina-guides-secure-restful-service"
}

@kubernetes:Deployment {
    image:"ballerina.guides.io/secure_restful_service:v1.0",
    name:"ballerina-guides-secure-restful-service"
}

listener http:Listener httpListener = new(9090, config = {
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
    auth: { authHandlers: [basicAuthHandler] }
});

// Order management is done using an in memory map.
// Add some sample orders to 'orderMap' at startup.
map<json> ordersMap = {};

// RESTful service.
@http:ServiceConfig {
    basePath: "/ordermgt",
    authConfig: {
        authentication: { enabled: true }
    }
}
service order_mgt on httpListener {
```

- Here we have used ``  @kubernetes:Deployment `` to specify the Docker image name which will be created as part of building this service.
- We have also specified `` @kubernetes:Service {} `` so that it will create a Kubernetes service which will expose the Ballerina service that is running on a Pod.  
- In addition we have used `` @kubernetes:Ingress `` which is the external interface to access your service (with path `` /`` and host name ``ballerina.guides.io``)

If you are using Minikube, you need to set a couple of additional attributes to the `@kubernetes:Deployment` annotation.
- `dockerCertPath` - The path to the certificates directory of Minikube (e.g., `/home/ballerina/.minikube/certs`).
- `dockerHost` - The host for the running cluster (e.g., `tcp://192.168.99.100:2376`). The IP address of the cluster can be found by running the `minikube ip` command.

- Now you can build a Ballerina executable archive (.jar) of the service that we developed above by using the following command. It points to the service file that we developed above and it creates an executable binary out of that.
This also creates the corresponding Docker image and the Kubernetes artifacts using the Kubernetes annotations that you have configured above.

```
   $ ballerina build secure_restful_service --skiptests

   Run following command to deploy kubernetes artifacts:  
   kubectl apply -f ./target/kubernetes/secure_restful_service
```

- You can verify that the Docker image that we specified in `@kubernetes:Deployment` is created, by using `docker images`.
- Also, the Kubernetes artifacts related to your service is generated in `./target/secure_restful_service/kubernetes`.
- Now you can create the Kubernetes deployment using:

```
   $ kubectl apply -f ./target/kubernetes/secure_restful_service

   deployment.extensions "ballerina-guides-secure-restful-service" created
   ingress.extensions "ballerina-guides-secure-restful-service" created
   secret "listener-secure-socket" created
   service "ballerina-guides-secure-restful-service" created
```

- You can verify if the Kubernetes deployment, service, and ingress are running properly by using the following Kubernetes commands.

```
   $ kubectl get service
   $ kubectl get deploy
   $ kubectl get pods
   $ kubectl get ingress
```

- If everything is successfully deployed, you can invoke the service either via Node port or ingress.

Node Port:

```
curl -kv -X POST -u counter:ballerina -d \
'{ "Order": { "ID": "100500", "Name": "XYZ", "Description": "Sample order."}}' \
"https://<Minikube_host_IP>:<Node_Port>/ordermgt/order" -H "Content-Type:application/json"
```


## Observability
Ballerina is by default observable. Meaning you can easily observe your services, resources, etc.
However, observability is disabled by default via configuration. Observability can be enabled by adding the following configurations to `ballerina.conf` file in `secure-restful-service/src/`.

```ballerina
[observability]

[observability.metrics]
# Flag to enable Metrics
enabled=true

[observability.tracing]
# Flag to enable Tracing
enabled=true
```

### Tracing
You can monitor Ballerina services using in-built tracing capabilities off Ballerina. We use [Jaeger](https://github.com/jaegertracing/jaeger) as the distributed tracing system here.
Follow the following steps to use tracing with Ballerina.

- Run Jaeger Docker image using the following command
```bash
   docker run -d -p5775:5775/udp -p6831:6831/udp -p6832:6832/udp -p5778:5778 -p16686:16686
   -p14268:14268 jaegertracing/all- in-one:latest
```

- Navigate to `secure-restful-service/src/` and run the 'secure_restful_service' program using following command
```
   $ ballerina run secure_restful_service/
```

- Observe the tracing using Jaeger UI by accessing the following URL.
```
   http://localhost:16686
```

- You should see the Jaeger UI as follows

   ![Jaeger UI](images/tracing-screenshot.png "Tracing Screenshot")


### Metrics
Metrics and alerts are built-in with Ballerina. We use Prometheus as the monitoring tool.
Follow the steps below to set up Prometheus and view metrics for Ballerina RESTful service.

- Set the below configurations in the `ballerina.conf` file in the project root, in addition to the user related configuration.
```ballerina
   [observability.metrics.prometheus]
   # Flag to enable Prometheus HTTP endpoint
   enabled=true
   # Prometheus HTTP endpoint port. Metrics will be exposed in /metrics context.
   # Eg: http://localhost:9797/metrics
   port=9797
   # Flag to indicate whether meter descriptions should be sent to Prometheus.
   descriptions=false
   # The step size to use in computing windowed statistics like max. The default is 1 minute.
   step="PT1M"
```

- Create a file `prometheus.yml` inside `/etc/` location. Add the below configurations to the `prometheus.yml` file.
```
   global:
   scrape_interval:     15s
   evaluation_interval: 15s

   scrape_configs:
    - job_name: 'prometheus'

   static_configs:
        - targets: ['172.17.0.1:9797']
```

    > **Note** : Replace `172.17.0.1` if your local Docker IP differs from `172.17.0.1`.

- Run the Prometheus Docker image using the following command.
```
   docker run -p 19090:9090 -v /tmp/prometheus.yml prom/prometheus
```

- You can access Prometheus at the following URL.
```
   http://localhost:19090/
```

- Promethues UI with metrics for secure_restful_service.

   ![promethues screenshot](images/metrics-screenshot.png "Prometheus UI")

### Logging
Ballerina has a log package for logging to the console. You can `import ballerina/log` package and start logging. The following section describes how to search, analyze, and visualize logs in real time using Elastic Stack.

- Start Elasticsearch using the following command.
```
   docker run -p 9200:9200 -p 9300:9300 -it -h elasticsearch --name
   elasticsearch docker.elastic.co/elasticsearch/elasticsearch:6.5.1
```

   NOTE: Linux users might need to run `sudo sysctl -w vm.max_map_count=262144` to increase `vm.max_map_count`.

- Start Kibana plugin for data visualization with Elasticsearch.
```
   docker run -p 5601:5601 -h kibana --name kibana --link elasticsearch:elasticsearch
   docker.elastic.co/kibana/kibana:6.5.1   
```

- Configure logstash to format the Ballerina logs.

    i) Create a file named `logstash.conf` with the following content.

    ```
    input {
        beats {
           port => 5044
        }
    }

    filter {
        grok  {
            match => {
                "message" => "%{TIMESTAMP_ISO8601:date}%{SPACE}%{WORD:logLevel}%{SPACE}
                \[%{GREEDYDATA:package}\]%{SPACE}\-%{SPACE}%{GREEDYDATA:logMessage}"
            }
        }
    }

    output {
        elasticsearch {
            hosts => "elasticsearch:9200"
            index => "store"
            document_type => "store_logs"
        }
    }
    ```

    ii) Save the above `logstash.conf` inside a directory named `{SAMPLE_ROOT_DIRECTORY}\pipeline`.

    iii) Start the logstash container, replace the {SAMPLE_ROOT_DIRECTORY} with your directory name.

    ```
    docker run -h logstash --name logstash --link elasticsearch:elasticsearch -it --rm
        -v ~/{SAMPLE_ROOT_DIRECTIRY}/pipeline:/usr/share/logstash/pipeline/
        -p 5044:5044 docker.elastic.co/logstash/logstash:6.5.1
    ```

 - Configure filebeat to ship the Ballerina logs.

     i) Create a file named `filebeat.yml` with the following content.
    ```
    filebeat.prospectors:
      - type: log
    paths:
      - /usr/share/filebeat/ballerina.log
    output.logstash:
        hosts: ["logstash:5044"]
    ```
     ii) Save the above `filebeat.yml` inside a directory named as `{SAMPLE_ROOT_DIRECTORY}\filebeat`.  

     iii) Start the logstash container and replace the {SAMPLE_ROOT_DIRECTORY} with your directory name.

    ```
    docker run -v {SAMPLE_ROOT_DIRECTORY}/filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml
        -v {SAMPLE_ROOT_DIRECTORY}/src/secure_restful_service/ballerina.log:/usr/share/filebeat/ballerina.log
        --link logstash:logstash docker.elastic.co/beats/filebeat:6.5.1
    ```

 - Access Kibana to visualize the logs using following URL.
```
http://localhost:5601
```

 - Kibana log visualization for the restful service sample.

     ![logging screenshot](images/logging-screenshot.png "Kibana UI")
