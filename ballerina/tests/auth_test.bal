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
import ballerina/test;

final Authenticator basicAuth = check new ([{fileUserStoreConfig: {}}]);
final Authenticator adminByDefault = check new ([{fileUserStoreConfig: {}, scopes: "hr:admin"}]);

function request(string method, string? credential = ()) returns http:Request {
    http:Request request = new;
    request.method = method;
    if credential is string {
        request.setHeader("Authorization", "Basic " + credential.toBytes().toBase64());
    }
    return request;
}

function authenticated(Authenticator authenticator, string credential) returns graphql:Context|error {
    graphql:Context ctx = new;
    check authenticator.authenticate(ctx, request(http:POST, credential));
    return ctx;
}

@test:Config
function testNoProvider() {
    Authenticator|error authenticator = new ([]);
    if authenticator !is error {
        test:assertFail("no provider");
    }
    test:assertEquals(authenticator.message(), "The configurable value 'dataserviceConfig.serviceConfig.auth' " +
            "must hold at least one authentication provider.");
}

@test:Config
function testMissingAndInvalidCredentials() {
    foreach string? credential in [(), "reader:wrong", "nobody:x"] {
        graphql:AuthnError|graphql:AuthzError? err = basicAuth.authenticate(new, request(http:POST, credential));
        if err !is graphql:AuthnError {
            test:assertFail(credential.toString());
        }
        test:assertEquals(err.message(), "The request needs a valid credential.");
        test:assertEquals(err.detail()["extensions"], {code: "UNAUTHENTICATED"});
    }
}

@test:Config
function testBearerCredentialIsNotTriedOnAUserStore() {
    http:Request bearer = request(http:POST);
    bearer.setHeader("Authorization", "Bearer abc");
    test:assertTrue(basicAuth.authenticate(new, bearer) is graphql:AuthnError);
}

@test:Config
function testOnlyPost() {
    graphql:AuthnError|graphql:AuthzError? err = basicAuth.authenticate(new, request(http:GET, "reader:reader-pass"));
    if err !is graphql:AuthzError {
        test:assertFail("GET");
    }
    test:assertEquals(err.message(), "A request to a data service with auth must use POST.");
}

@test:Config
function testScopes() returns error? {
    graphql:Context reader = check authenticated(basicAuth, "reader:reader-pass");
    test:assertTrue(hasScope(reader, ["hr:read"]));
    test:assertTrue(hasScope(reader, ["hr:admin", "hr:read"]));
    test:assertFalse(hasScope(reader, ["hr:admin"]));
    test:assertEquals(checkScopes(reader, ["hr:read"]), ());
    Error? forbidden = checkScopes(reader, ["hr:admin"]);
    if forbidden is () {
        test:assertFail("hr:admin");
    }
    test:assertEquals(forbidden.detail(), {
        message: "The caller holds no scope that the operation needs.",
        extensions: {code: "FORBIDDEN"}
    });
}

@test:Config
function testEmptyListTakesTheProviderScopes() returns error? {
    // Without provider scopes, the credential alone is enough.
    test:assertTrue(hasScope(check authenticated(basicAuth, "guest:guest-pass"), []));
    test:assertFalse(hasScope(check authenticated(adminByDefault, "reader:reader-pass"), []));
    test:assertTrue(hasScope(check authenticated(adminByDefault, "admin:admin-pass"), []));
}

@test:Config
function testNoCallerHoldsNoScope() {
    test:assertFalse(hasScope(new, []));
}
