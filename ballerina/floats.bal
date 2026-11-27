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
import ballerina/log;

# Checks that an input `float` is a finite number. ballerina/graphql takes a literal such as `1e400` as `Infinity`.
#
# + value - The value
# + entity - The name of the entity
# + 'field - The name of the field
# + return - The `INVALID_INPUT` error when the value is `NaN` or infinite
public isolated function checkFinite(float value, string entity, string 'field) returns Error? {
    if value.isFinite() {
        return ();
    }
    return toError({
        code: dataservice:INVALID_INPUT,
        message: string `The field '${'field}' of the entity '${entity}' is not a finite number.`
    });
}

# Returns a stored `float`, which JSON cannot hold when it is `NaN` or infinite.
#
# + value - The stored value
# + entity - The name of the entity
# + 'field - The name of the field
# + return - The value, or the `INTERNAL` error when it is not finite
public isolated function toFinite(float value, string entity, string 'field) returns float|Error {
    if value.isFinite() {
        return value;
    }
    string message = string `The field '${'field}' of the entity '${entity}' holds a value that is not a finite number.`;
    log:printError(message, entity = entity, 'field = 'field);
    return toError({code: dataservice:INTERNAL, message});
}
