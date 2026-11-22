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
import ballerina/auth;
import ballerina/dataservice;
import ballerina/graphql;
import ballerina/http;
import ballerina/jwt;
import ballerina/oauth2;

// The provider handling is that of `ballerina/dataservice.http`'s Authenticator, duplicated here: a protocol package
// does not import another one.

type AuthHandler http:ListenerFileUserStoreBasicAuthHandler|http:ListenerLdapUserStoreBasicAuthHandler
    |http:ListenerJwtAuthHandler|http:ListenerOAuth2Handler;

const CALLER = "dataservice.caller";

final string:RegExp WHITESPACE = re `\s`;

# Authenticates each request of a data service with auth, before ballerina/graphql parses and validates its document.
public isolated class Authenticator {
    private final Provider[] providers = [];

    # Creates the authenticator from the configured providers.
    #
    # + providers - The authentication providers, such as a JWT validator
    # + return - An error when no provider is configured
    public isolated function init(graphql:ListenerAuthConfig[] providers) returns error? {
        if providers.length() == 0 {
            return error("The configurable value 'dataserviceConfig.serviceConfig.auth' must hold at least one " +
                "authentication provider.");
        }
        foreach graphql:ListenerAuthConfig provider in providers {
            AuthHandler handler;
            string scheme = http:AUTH_SCHEME_BEARER;
            string scopeKey = "";
            if provider is graphql:FileUserStoreConfigWithScopes {
                handler = new http:ListenerFileUserStoreBasicAuthHandler(provider.fileUserStoreConfig);
                scheme = http:AUTH_SCHEME_BASIC;
            } else if provider is graphql:LdapUserStoreConfigWithScopes {
                handler = new http:ListenerLdapUserStoreBasicAuthHandler(provider.ldapUserStoreConfig.cloneReadOnly());
                scheme = http:AUTH_SCHEME_BASIC;
            } else if provider is graphql:JwtValidatorConfigWithScopes {
                handler = new http:ListenerJwtAuthHandler(provider.jwtValidatorConfig.cloneReadOnly());
            } else {
                handler = new http:ListenerOAuth2Handler(provider.oauth2IntrospectionConfig.cloneReadOnly());
                scopeKey = provider.oauth2IntrospectionConfig.scopeKey;
            }
            string|string[]? configured = provider?.scopes;
            readonly & string[]? scopes;
            if configured is string {
                scopes = [configured];
            } else {
                scopes = configured.cloneReadOnly();
            }
            lock {
                self.providers.push({handler, scheme, scopeKey, scopes});
            }
        }
    }

    # Authenticates a request and keeps the caller in the context, as `contextInit` calls it.
    #
    # + ctx - The request context
    # + request - The HTTP request
    # + return - `graphql:AuthnError` without a valid credential, `graphql:AuthzError` for a request other than `POST`
    public isolated function authenticate(graphql:Context ctx, http:Request request)
            returns graphql:AuthnError|graphql:AuthzError? {
        // ballerina/graphql runs mutations sent with GET, and a browser sends saved basic auth credentials with a
        // cross-site GET, so a service with auth takes only POST.
        if request.method != http:POST {
            return error graphql:AuthzError("A request to a data service with auth must use POST.");
        }
        Caller? caller = self.toCaller(request);
        if caller is () {
            dataservice:DataserviceError body = dataservice:toUnauthenticatedError();
            return error graphql:AuthnError(body.message, message = body.message, extensions = {code: body.code});
        }
        ctx.set(CALLER, caller);
    }

    // As ballerina/http does, a `Basic` credential is tried only with the user stores and a `Bearer` credential only
    // with the JWT and OAuth2 providers, in the order of the providers, and the first that accepts it decides.
    isolated function toCaller(http:Request request) returns Caller? {
        string|http:HeaderNotFoundError header = request.getHeader("Authorization");
        if header is http:HeaderNotFoundError {
            return ();
        }
        string scheme = WHITESPACE.split(header)[0];
        int count;
        lock {
            count = self.providers.length();
        }
        foreach int i in 0 ..< count {
            AuthHandler handler;
            string providerScheme;
            string scopeKey;
            readonly & string[]? providerScopes;
            lock {
                Provider provider = self.providers[i];
                handler = provider.handler;
                providerScheme = provider.scheme;
                scopeKey = provider.scopeKey;
                providerScopes = provider.scopes;
            }
            if providerScheme != scheme {
                continue;
            }
            if handler is http:ListenerFileUserStoreBasicAuthHandler {
                auth:UserDetails|http:Unauthorized user = handler.authenticate(request);
                if user is auth:UserDetails {
                    return new (handler, scopeKey, user.cloneReadOnly(), providerScopes);
                }
            } else if handler is http:ListenerLdapUserStoreBasicAuthHandler {
                auth:UserDetails|http:Unauthorized user = handler->authenticate(request);
                if user is auth:UserDetails {
                    return new (handler, scopeKey, user.cloneReadOnly(), providerScopes);
                }
            } else if handler is http:ListenerJwtAuthHandler {
                jwt:Payload|http:Unauthorized payload = handler.authenticate(request);
                if payload !is http:Unauthorized {
                    return new (handler, scopeKey, (<jwt:Payload>payload).cloneReadOnly(), providerScopes);
                }
            } else if handler is http:ListenerOAuth2Handler {
                oauth2:IntrospectionResponse|http:Unauthorized|http:Forbidden response = handler->authorize(request);
                if response is oauth2:IntrospectionResponse {
                    return new (handler, scopeKey, response.cloneReadOnly(), providerScopes);
                }
            }
        }
        return ();
    }
}

type Provider record {|
    AuthHandler handler;
    string scheme;
    string scopeKey;
    readonly & string[]? scopes;
|};

// The authenticated caller of a request. Its scopes are checked as the handler that authenticated it checks them.
isolated class Caller {
    private final AuthHandler handler;
    private final string scopeKey;
    private final readonly & (auth:UserDetails|jwt:Payload|oauth2:IntrospectionResponse) details;
    private final readonly & string[]? providerScopes;

    isolated function init(AuthHandler handler, string scopeKey,
            readonly & (auth:UserDetails|jwt:Payload|oauth2:IntrospectionResponse) details,
            readonly & string[]? providerScopes) {
        self.handler = handler;
        self.scopeKey = scopeKey;
        self.details = details;
        self.providerScopes = providerScopes;
    }

    // An empty list takes the provider's scopes; without those, the credential alone is enough.
    isolated function isAllowed(string[] scopes) returns boolean {
        string[]? required = scopes.length() > 0 ? scopes : self.providerScopes;
        return required is () || required.length() == 0 || self.hasScope(required);
    }

    isolated function hasScope(string[] scopes) returns boolean {
        AuthHandler handler = self.handler;
        readonly & (auth:UserDetails|jwt:Payload|oauth2:IntrospectionResponse) details = self.details;
        if handler is http:ListenerFileUserStoreBasicAuthHandler {
            return handler.authorize(<auth:UserDetails>details, scopes) is ();
        }
        if handler is http:ListenerLdapUserStoreBasicAuthHandler {
            http:Forbidden? refused = handler->authorize(<auth:UserDetails>details, scopes);
            return refused is ();
        }
        if handler is http:ListenerJwtAuthHandler {
            return handler.authorize(<jwt:Payload>details, scopes) is ();
        }
        // As `http:ListenerOAuth2Handler` does, the scope claim is a whitespace-separated string.
        anydata held = (<oauth2:IntrospectionResponse>details)[self.scopeKey];
        if held !is string {
            return false;
        }
        string[] heldScopes = WHITESPACE.split(held);
        foreach string scope in scopes {
            if heldScopes.indexOf(scope) !is () {
                return true;
            }
        }
        return false;
    }
}

isolated function callerOf(graphql:Context ctx) returns Caller? {
    any|error caller = ctx.get(CALLER);
    return caller is Caller ? caller : ();
}

# Checks that the caller holds one of the scopes of a root field's action.
#
# + ctx - The request context, which holds the caller
# + scopes - The scopes of the action; an empty list takes the provider's scopes
# + return - The `FORBIDDEN` error when the caller holds none
public isolated function checkScopes(graphql:Context ctx, string[] scopes) returns Error? =>
    hasScope(ctx, scopes) ? () : toError(dataservice:toNoScopeError());

# Tells whether the caller holds one of the scopes, as patch and delete check before they return the record.
#
# + ctx - The request context, which holds the caller
# + scopes - The scopes; an empty list takes the provider's scopes
# + return - `true` when the caller holds one
public isolated function hasScope(graphql:Context ctx, string[] scopes) returns boolean {
    Caller? caller = callerOf(ctx);
    return caller is Caller && caller.isAllowed(scopes);
}

# The related entity of a relation and its `read` scopes, which a caller needs to read the relation.
#
# + target - The name of the related entity
# + scopes - The `read` scopes of the related entity
public type RelationScopes record {|
    string target;
    string[] scopes;
|};

# Checks that the caller may read each relation that a root field's selection reads, once, before the read.
#
# + ctx - The request context, which holds the caller
# + 'field - The root field
# + entity - The name of the entity the root field returns
# + relations - The related entity and its `read` scopes, by relation field
# + entityScopes - For a mutation's result, the entity's own `read` scopes, which a selected relation also needs
# + return - The `FORBIDDEN` error for the first relation the caller cannot read
public isolated function checkRelationScopes(graphql:Context ctx, graphql:Field 'field, string entity,
        map<RelationScopes> relations, string[]? entityScopes = ()) returns Error? {
    string[] selected = from string name in toSelectedNames('field)
        where relations.hasKey(name)
        select name;
    if selected.length() == 0 {
        return ();
    }
    if entityScopes is string[] && !hasScope(ctx, entityScopes) {
        return toError(dataservice:toNoScopeError());
    }
    foreach string relation in selected {
        RelationScopes related = relations.get(relation);
        if !hasScope(ctx, related.scopes) {
            return toError(dataservice:toForbiddenError(entity, relation, related.target));
        }
    }
    return ();
}
