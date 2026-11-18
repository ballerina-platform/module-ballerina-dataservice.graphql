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
import ballerina/dataservice;
import ballerina/graphql;

# The settings of the generated service that vary by environment.
#
# + cors - The CORS settings; no cross-origin request is allowed by default
# + maxQueryDepth - The deepest document the service runs; GraphiQL's introspection query has depth 13
# + maxQueryComplexity - The largest complexity of a document the service runs; a field counts 1, and a to-many
# relation field 20
public type ServiceConfig record {|
    graphql:CorsConfig cors = {};
    int maxQueryDepth = 15;
    int maxQueryComplexity = 100;
|};

# The runtime settings of a generated GraphQL data service, the type of its configurable `dataserviceConfig`.
#
# + listenerConfig - The other settings of the listener, such as TLS
# + serviceConfig - The settings of the service
public type Config record {|
    *dataservice:Config;
    graphql:ListenerConfiguration listenerConfig = {};
    ServiceConfig serviceConfig = {};
|};

# The settings of a generated service with auth.
#
# + auth - The authentication providers, such as a JWT validator
public type AuthServiceConfig record {|
    *ServiceConfig;
    graphql:ListenerAuthConfig[] auth;
|};

# The runtime settings of a generated GraphQL data service with auth.
#
# + listenerConfig - The other settings of the listener, such as TLS
# + serviceConfig - The settings of the service, with the authentication providers
public type AuthConfig record {|
    *dataservice:Config;
    graphql:ListenerConfiguration listenerConfig = {};
    AuthServiceConfig serviceConfig;
|};

# Checks the limits of a service at startup, so that a value out of range stops the program.
#
# + config - The settings of the service
# + return - An error naming the first limit below 1
public isolated function checkLimits(ServiceConfig|AuthServiceConfig config) returns error? {
    foreach [string, int] [name, value] in [
            ["maxQueryDepth", config.maxQueryDepth], ["maxQueryComplexity", config.maxQueryComplexity]] {
        // ballerina/graphql takes a complexity of 0 as no limit, which the service does not allow.
        if value < 1 {
            return error(string `The configurable value 'dataserviceConfig.serviceConfig.${name}' must be at least 1, ` +
                    string `found ${value}.`);
        }
    }
}
