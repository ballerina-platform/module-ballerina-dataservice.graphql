// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
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
import ballerina/graphql;
import ballerina/http;
import ballerina/scan;
import ballerina/test;

final readonly & map<RelationScopes> orderRelations = {"department": {target: "Department", scopes: ["hr:admin"]}};

@scan:Suppress {rules: [scan:UNUSED_FUNCTION_PARAMETER], reason: "The signature of a contextInit function"}
isolated function initOrderContext(http:RequestContext requestContext, http:Request request)
        returns graphql:Context|error {
    graphql:Context ctx = new;
    check basicAuth.authenticate(ctx, request);
    return ctx;
}

@scan:Suppress {rules: [scan:UNUSED_FUNCTION_PARAMETER], reason: "The signature of a contextInit function"}
isolated function initAdminByDefaultContext(http:RequestContext requestContext, http:Request request)
        returns graphql:Context|error {
    graphql:Context ctx = new;
    check adminByDefault.authenticate(ctx, request);
    return ctx;
}

public isolated service class TestDepartmentObject {
    isolated resource function get name() returns string => "Research";
}

// An entity may have a scalar field named `items`, like the records of a page.
public isolated service class TestOrderObject {
    isolated resource function get items() returns int => 3;

    isolated resource function get department() returns TestDepartmentObject => new;
}

public type TestOrderList record {|
    TestOrderObject[] items;
    boolean hasMore;
|};

@graphql:ServiceConfig {contextInit: initOrderContext}
service /orders on new graphql:Listener(9598) {
    isolated resource function get 'order(graphql:Context ctx, graphql:Field 'field) returns TestOrderObject?|error {
        check checkRelationScopes(ctx, 'field, "Order", orderRelations);
        return new;
    }

    isolated resource function get orders(graphql:Context ctx, graphql:Field 'field) returns TestOrderList?|error {
        check checkRelationScopes(ctx, 'field, "Order", orderRelations);
        return {items: [new], hasMore: false};
    }

    // As a mutation's result, which also needs the entity's own `read` scopes when a relation is selected.
    isolated resource function get adminOrder(graphql:Context ctx, graphql:Field 'field) returns TestOrderObject?|error {
        check checkRelationScopes(ctx, 'field, "Order", orderRelations, ["hr:admin"]);
        return new;
    }

    isolated resource function get readerOrder(graphql:Context ctx, graphql:Field 'field)
            returns TestOrderObject?|error {
        check checkRelationScopes(ctx, 'field, "Order", orderRelations, ["hr:read"]);
        return new;
    }
}

final readonly & map<RelationScopes> providerScopedRelations = {"department": {target: "Department", scopes: []}};

@graphql:ServiceConfig {contextInit: initAdminByDefaultContext}
service /providerScoped on new graphql:Listener(9599) {
    isolated resource function get 'order(graphql:Context ctx, graphql:Field 'field) returns TestOrderObject?|error {
        check checkRelationScopes(ctx, 'field, "Order", providerScopedRelations);
        return new;
    }
}

final http:Client orderClient = check new ("http://localhost:9598/orders");
final http:Client providerScopedClient = check new ("http://localhost:9599/providerScoped");

@scan:Suppress {rules: [scan:HARD_CODED_SECRET], reason: "Test-only basic-auth credentials of the test user store"}
function postOrderQuery(string document, http:Client 'client = orderClient) returns json|error {
    return 'client->post("", {query: document}, {"Authorization": "Basic " + "reader:reader-pass".toBytes().toBase64()});
}

@test:Config {dataProvider: relationDocuments}
function testRelationBesideAnItemsField(string document, string path) returns error? {
    json response = check postOrderQuery(document);
    test:assertEquals(check response.errors, [
        {
            message: "The relation 'department' of the entity 'Order' needs a 'read' scope of the entity 'Department'.",
            locations: [{line: 1, column: 3}],
            path: [path],
            extensions: {code: "FORBIDDEN"}
        }
    ]);
}

function relationDocuments() returns [string, string][] => [
    ["{ order { items department { name } } }", "order"],
    ["{ orders { items { items department { name } } } }", "orders"],
    ["{ order { d: department { name } } }", "order"],
    ["{ o: order { department { name } } }", "o"],
    ["{ order { ...withDepartment } } fragment withDepartment on TestOrderObject { department { name } }", "order"],
    ["{ order { ... on TestOrderObject { department { name } } } }", "order"],
    ["{ orders { items { ...withDepartment } } } fragment withDepartment on TestOrderObject { department { name } }",
        "orders"],
    ["{ order { department @skip(if: false) { name } } }", "order"],
    ["{ order { department @include(if: true) { name } } }", "order"],
    ["{ orders { a: items { items } b: items { department { name } } } }", "orders"],
    ["{ orders { a: items { department { name } } b: items { items } } }", "orders"]
];

@test:Config
function testEntityScopesAreCheckedFirst() returns error? {
    json response = check postOrderQuery("{ adminOrder { department { name } } }");
    test:assertEquals(check response.errors, [
        {
            message: "The caller holds no scope that the operation needs.",
            locations: [{line: 1, column: 3}],
            path: ["adminOrder"],
            extensions: {code: "FORBIDDEN"}
        }
    ]);
}

@test:Config
function testRelationScopesFollowTheEntityScopes() returns error? {
    json response = check postOrderQuery("{ readerOrder { department { name } } }");
    test:assertEquals(check response.errors, [
        {
            message: "The relation 'department' of the entity 'Order' needs a 'read' scope of the entity 'Department'.",
            locations: [{line: 1, column: 3}],
            path: ["readerOrder"],
            extensions: {code: "FORBIDDEN"}
        }
    ]);
}

@test:Config
function testEntityScopesWithoutARelation() returns error? {
    json response = check postOrderQuery("{ adminOrder { items } }");
    test:assertEquals(response, {data: {adminOrder: {items: 3}}});
}

@test:Config
function testRelationTakesTheProviderScopes() returns error? {
    json response = check postOrderQuery("{ order { department { name } } }", providerScopedClient);
    test:assertEquals(check response.errors, [
        {
            message: "The relation 'department' of the entity 'Order' needs a 'read' scope of the entity 'Department'.",
            locations: [{line: 1, column: 3}],
            path: ["order"],
            extensions: {code: "FORBIDDEN"}
        }
    ]);
}

@test:Config
function testMissingCredentialIsAnHttpError() returns error? {
    http:Response response = check orderClient->post("", {query: "{ order { items } }"});
    test:assertEquals(response.statusCode, 400);
    json body = check response.getJsonPayload();
    test:assertEquals(check body.errors, [
        {message: "The request needs a valid credential.", extensions: {code: "UNAUTHENTICATED"}}
    ]);
}

@test:Config
function testSkippedRelationNeedsNoRelationScope() returns error? {
    json response = check postOrderQuery("{ order { items department @skip(if: true) { name } } " +
            "orders { items { items department @include(if: false) { name } } } }");
    test:assertEquals(response, {data: {'order: {items: 3}, orders: {items: [{items: 3}]}}});
}

@test:Config
function testScalarItemsFieldNeedsNoRelationScope() returns error? {
    json response = check postOrderQuery("{ order { items } orders { items { items } } }");
    test:assertEquals(response, {data: {'order: {items: 3}, orders: {items: [{items: 3}]}}});
}
