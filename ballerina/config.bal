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
public type ServiceConfig record {|
    graphql:CorsConfig cors = {};
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
