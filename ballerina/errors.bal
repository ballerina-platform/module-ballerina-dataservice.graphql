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

# An error that a generated service returns from a field: its message is the message of the error category, and
# `extensions.code` is the category's code.
public type Error distinct graphql:ServiceError;

# Maps an error from reading many records to the `INTERNAL` error, and logs it.
#
# + err - The error the persist client returned
# + entity - The name of the entity
# + operation - The name of the operation, which is logged with the error
# + return - The `INTERNAL` error
public isolated function toListError(error err, string entity, string operation = "get many") returns Error =>
    toError(dataservice:toInternalErrorBody(err, entity, operation));

isolated function toError(dataservice:DataserviceError body) returns Error =>
    error Error(body.message, message = body.message, extensions = {code: body.code});
