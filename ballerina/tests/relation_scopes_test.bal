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

isolated function initOrderContext(http:RequestContext requestContext, http:Request request)
        returns graphql:Context|error {
    graphql:Context ctx = new;
    check basicAuth.authenticate(ctx, request);
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
}

final http:Client orderClient = check new ("http://localhost:9598/orders");

@scan:Suppress {rules: [scan:HARD_CODED_SECRET], reason: "Test-only basic-auth credentials of the test user store"}
function postOrderQuery(string document) returns json|error {
    return orderClient->post("", {query: document}, {"Authorization": "Basic " + "reader:reader-pass".toBytes().toBase64()});
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
    ["{ orders { items { items department { name } } } }", "orders"]
];

@test:Config
function testScalarItemsFieldNeedsNoRelationScope() returns error? {
    json response = check postOrderQuery("{ order { items } orders { items { items } } }");
    test:assertEquals(response, {data: {'order: {items: 3}, orders: {items: [{items: 3}]}}});
}
