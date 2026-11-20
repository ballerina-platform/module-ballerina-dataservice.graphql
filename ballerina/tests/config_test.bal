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
import ballerina/test;

@test:Config
function testConfigDefaults() {
    Config config = {};
    test:assertEquals(config.port, 9090);
    test:assertEquals(config.pageSize, 100);
    test:assertEquals(config.maxPageSize, 1000);
    test:assertEquals(config.serviceConfig.cors.allowOrigins, []);
    test:assertEquals(config.serviceConfig.maxQueryDepth, 15);
    test:assertEquals(config.serviceConfig.maxQueryComplexity, 100);
}

@test:Config
function testCheckLimits() {
    test:assertEquals(checkLimits({}), ());
    test:assertEquals(checkLimits({maxQueryDepth: 1, maxQueryComplexity: 1}), ());
    test:assertEquals(checkLimits(<AuthServiceConfig>{auth: []}), ());
    error? depth = checkLimits({maxQueryDepth: 0});
    test:assertEquals(depth is error ? depth.message() : (),
            "The configurable value 'dataserviceConfig.serviceConfig.maxQueryDepth' must be at least 1, found 0.");
    error? complexity = checkLimits(<AuthServiceConfig>{maxQueryComplexity: -5, auth: []});
    test:assertEquals(complexity is error ? complexity.message() : (),
            "The configurable value 'dataserviceConfig.serviceConfig.maxQueryComplexity' must be at least 1, found -5.");
}
