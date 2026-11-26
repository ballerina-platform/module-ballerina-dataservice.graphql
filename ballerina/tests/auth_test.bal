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
import ballerina/jwt;
import ballerina/random;
import ballerina/scan;
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

@scan:Suppress {rules: [scan:HARD_CODED_SECRET], reason: "Test-only basic-auth credentials of the test user store"}
@test:Config
function testOnlyPost() {
    graphql:AuthnError|graphql:AuthzError? err = basicAuth.authenticate(new, request(http:GET, "reader:reader-pass"));
    if err !is graphql:AuthzError {
        test:assertFail("GET");
    }
    test:assertEquals(err.message(), "A request to a data service with auth must use POST.");
}

@scan:Suppress {rules: [scan:HARD_CODED_SECRET], reason: "Test-only basic-auth credentials of the test user store"}
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

@scan:Suppress {rules: [scan:HARD_CODED_SECRET], reason: "Test-only basic-auth credentials of the test user store"}
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

// An OAuth2 introspection endpoint whose active token holds two scopes separated by a tab.
service /oauth2 on new http:Listener(9597) {
    resource function post introspect(http:Request request) returns json|error {
        map<string> form = check request.getFormParams();
        return form["token"] == "tab-token" ? {active: true, scope: "hr:read\tdepartments:read"} : {active: false};
    }
}

final Authenticator oauth2Auth = check new ([
    {oauth2IntrospectionConfig: {url: "http://localhost:9597/oauth2/introspect"}}
]);

@test:Config
function testOAuth2ScopesSplitOnAnyWhitespace() returns error? {
    http:Request bearer = request(http:POST);
    bearer.setHeader("Authorization", "Bearer tab-token");
    graphql:Context ctx = new;
    check oauth2Auth.authenticate(ctx, bearer);
    test:assertTrue(hasScope(ctx, ["departments:read"]));
    test:assertFalse(hasScope(ctx, ["hr:admin"]));
}

// A JWT secret made at run time, so the tests hold no secret.
final string jwtSecret = check randomSecret();

function randomSecret() returns string|error {
    string secret = "";
    foreach int i in 0 ..< 4 {
        secret += (check random:createIntInRange(100000000, 999999999)).toString();
    }
    return secret;
}

final graphql:JwtValidatorConfig & readonly jwtValidator = {issuer: "dataservice-test", signatureConfig: {secret: jwtSecret}};

function bearer(string token) returns http:Request {
    http:Request withToken = request(http:POST);
    withToken.setHeader("Authorization", "Bearer " + token);
    return withToken;
}

function issue(string scope, string secret = jwtSecret) returns string|error => jwt:issue({
    issuer: "dataservice-test",
    customClaims: {scope},
    signatureConfig: {algorithm: jwt:HS256, config: secret}
});

@test:Config
function testJwt() returns error? {
    Authenticator jwtAuth = check new ([{jwtValidatorConfig: jwtValidator}]);
    graphql:Context ctx = new;
    check jwtAuth.authenticate(ctx, bearer(check issue("hr:read")));
    test:assertTrue(hasScope(ctx, ["hr:read"]));
    test:assertFalse(hasScope(ctx, ["hr:admin"]));
    string forged = check issue("hr:admin", check randomSecret());
    test:assertTrue(jwtAuth.authenticate(new, bearer(forged)) is graphql:AuthnError);
}

@test:Config
function testFirstProviderThatAcceptsDecides() returns error? {
    string token = check issue("hr:read");
    Authenticator adminFirst = check new ([
        {jwtValidatorConfig: jwtValidator, scopes: "hr:admin"},
        {jwtValidatorConfig: jwtValidator, scopes: "hr:read"}
    ]);
    graphql:Context ctx = new;
    check adminFirst.authenticate(ctx, bearer(token));
    test:assertFalse(hasScope(ctx, []));
    Authenticator readerFirst = check new ([
        {jwtValidatorConfig: jwtValidator, scopes: "hr:read"},
        {jwtValidatorConfig: jwtValidator, scopes: "hr:admin"}
    ]);
    ctx = new;
    check readerFirst.authenticate(ctx, bearer(token));
    test:assertTrue(hasScope(ctx, []));
}
