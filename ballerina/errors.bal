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
import ballerina/log;
import ballerina/persist;

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

# Maps an error from reading one record to the `NOT_FOUND` or `INTERNAL` error.
#
# + err - The error the persist client returned
# + entity - The name of the entity
# + key - The values of the record's key fields, in key order
# + operation - The name of the operation, which is logged with the error
# + return - The `NOT_FOUND` or `INTERNAL` error
public isolated function toGetError(error err, string entity, dataservice:KeyValue[] key, string operation = "get one")
        returns Error {
    dataservice:DataserviceError body = dataservice:toErrorBody(err, entity, key, operation);
    return body.code == dataservice:NOT_FOUND ? toError(body) : toInternalError(err, entity, operation, body);
}

# Maps a value that is not in its format to the `INVALID_INPUT` error.
#
# + err - The error from the `ballerina/dataservice` conversion
# + entity - The name of the entity
# + 'field - The name of the field
# + return - The `INVALID_INPUT` error
public isolated function toInvalidInput(dataservice:ConversionError err, string entity, string 'field) returns Error =>
    toError({
        code: dataservice:INVALID_INPUT,
        message: string `The field '${'field}' of the entity '${entity}' is not ${err.detail().format}.`
    });

// A body of another category is replaced, and logged as internal, so that the code tells the category.
isolated function toInternalError(error err, string entity, string operation, dataservice:DataserviceError body)
        returns Error {
    if body.code == dataservice:INTERNAL {
        return toError(body);
    }
    if body.code == dataservice:CONSTRAINT_VIOLATION {
        // toErrorBody has already logged it.
        return toError({code: dataservice:INTERNAL, message: dataservice:INTERNAL_MESSAGE});
    }
    return toError(dataservice:toInternalErrorBody(err, entity, operation));
}

# Maps an error from creating records, or from reading the created records back, to its error.
#
# + err - The error the persist client returned
# + entity - The name of the entity
# + return - The `CONFLICT`, `CONSTRAINT_VIOLATION` or `INTERNAL` error
public isolated function toCreateError(error err, string entity) returns Error {
    dataservice:DataserviceError body = dataservice:toErrorBody(err, entity, operation = CREATE);
    return body.code == dataservice:CONFLICT || body.code == dataservice:CONSTRAINT_VIOLATION ? toError(body) :
        toInternalError(err, entity, CREATE, body);
}

# Maps an error from updating a record to its error. An update that is saved but cannot be read back has no error,
# and is logged.
#
# + err - The error the persist client returned
# + entity - The name of the entity
# + key - The values of the record's key fields, in key order
# + return - The `NOT_FOUND`, `CONFLICT`, `CONSTRAINT_VIOLATION` or `INTERNAL` error, or `()`
public isolated function toUpdateError(error err, string entity, dataservice:KeyValue[] key) returns Error? {
    if err is persist:ReadBackError {
        log:printError("A data service update was saved but could not be read back.", 'error = err, entity = entity,
                operation = PATCH_ONE);
        return ();
    }
    dataservice:DataserviceError body = dataservice:toErrorBody(err, entity, key, PATCH_ONE);
    return body.code == dataservice:INTERNAL ? toInternalError(err, entity, PATCH_ONE, body) : toError(body);
}

# Maps an error from deleting a record to its error.
#
# + err - The error the persist client returned
# + entity - The name of the entity
# + key - The values of the record's key fields, in key order
# + return - The `NOT_FOUND`, `CONSTRAINT_VIOLATION` or `INTERNAL` error
public isolated function toDeleteError(error err, string entity, dataservice:KeyValue[] key) returns Error {
    dataservice:DataserviceError body = dataservice:toErrorBody(err, entity, key, DELETE_ONE);
    return body.code == dataservice:NOT_FOUND || body.code == dataservice:CONSTRAINT_VIOLATION ? toError(body) :
        toInternalError(err, entity, DELETE_ONE, body);
}

# Maps a patch that both sets and unsets a field to the `INVALID_INPUT` error.
#
# + entity - The name of the entity
# + 'field - The name of the field
# + return - The `INVALID_INPUT` error
public isolated function toSetAndUnsetError(string entity, string 'field) returns Error => toError({
    code: dataservice:INVALID_INPUT,
    message: string `The field '${'field}' of the entity '${entity}' cannot be both set and unset.`
});

# Maps an error body of `ballerina/dataservice`, such as from `dataservice:checkCreateSize`, to its error.
#
# + body - The error body
# + return - The error, with the body's message and code
public isolated function toError(dataservice:DataserviceError body) returns Error =>
    error Error(body.message, message = body.message, extensions = {code: body.code});

const CREATE = "create";
const PATCH_ONE = "patch one";
const DELETE_ONE = "delete one";
