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
import ballerina/io;
import ballerina/persist;
import ballerina/test;

@test:Config
function testListError() {
    Error err = toListError(error persist:Error("connection refused"), "Employee");
    test:assertEquals(err.message(), dataservice:INTERNAL_MESSAGE);
    test:assertEquals(err.detail(), {message: dataservice:INTERNAL_MESSAGE, extensions: {code: "INTERNAL"}});
}

@test:Config
function testListErrorAnswersOtherCategoriesAsInternal() {
    Error err = toListError(error persist:NotFoundError("no row"), "Employee");
    test:assertEquals(err.detail().extensions, {code: "INTERNAL"});
}

@test:Config
function testGetErrorNotFound() {
    Error err = toGetError(error persist:NotFoundError("no row"), "Assignment", ["ATLAS", 1]);
    test:assertEquals(err.detail(), {
        message: "A record with the key 'ATLAS/1' does not exist for the entity 'Assignment'.",
        extensions: {code: "NOT_FOUND"}
    });
}

@test:Config
function testGetErrorOtherwiseInternal() {
    test:assertEquals(toGetError(error persist:Error("connection refused"), "Employee", [1]).detail().extensions,
            {code: "INTERNAL"});
    test:assertEquals(toGetError(error persist:ConstraintViolationError("fk"), "Employee", [1]).detail().extensions,
            {code: "INTERNAL"});
}

@test:Config
function testCreateErrors() {
    test:assertEquals(toCreateError(error persist:AlreadyExistsError("dup"), "Employee").detail(), {
        message: "A record that conflicts with an existing record of the entity 'Employee' already exists.",
        extensions: {code: "CONFLICT"}
    });
    test:assertEquals(toCreateError(error persist:ConstraintViolationError("fk"), "Employee").detail(), {
        message: "The operation violates a constraint of the entity 'Employee'.",
        extensions: {code: "CONSTRAINT_VIOLATION"}
    });
    test:assertEquals(toCreateError(error persist:NotFoundError("gone"), "Employee").detail().extensions,
            {code: "INTERNAL"});
}

@test:Config
function testUpdateErrors() {
    test:assertEquals((<Error>toUpdateError(error persist:NotFoundError("no row"), "Employee", [7])).detail(), {
        message: "A record with the key '7' does not exist for the entity 'Employee'.",
        extensions: {code: "NOT_FOUND"}
    });
    test:assertEquals((<Error>toUpdateError(error persist:AlreadyExistsError("dup"), "Employee", [7])).detail().extensions,
            {code: "CONFLICT"});
    test:assertTrue(toUpdateError(error persist:ReadBackError("gone"), "Employee", [7]) is ());
}

@test:Config
function testDeleteErrors() {
    test:assertEquals(toDeleteError(error persist:NotFoundError("no row"), "Employee", [7]).detail().extensions,
            {code: "NOT_FOUND"});
    test:assertEquals(toDeleteError(error persist:ConstraintViolationError("fk"), "Employee", [7]).detail().extensions,
            {code: "CONSTRAINT_VIOLATION"});
    test:assertEquals(toDeleteError(error persist:Error("down"), "Employee", [7]).detail().extensions,
            {code: "INTERNAL"});
}

@test:Config
function testNullError() {
    test:assertEquals(toNullError("Employee", "name").detail(), {
        message: "The field 'name' of the entity 'Employee' cannot be null.",
        extensions: {code: "INVALID_INPUT"}
    });
}

@test:Config {dataProvider: loggedErrors}
function testErrorIsLoggedOnceWithTheEntityAndOperation(string message, function (error err) returns Error? mapper,
        string expected) returns error? {
    Error? mapped = mapper(error persist:ConstraintViolationError(message));
    test:assertTrue(mapped is Error, message);
    string[] lines = from string line in check io:fileReadLines("target/errors_test.log")
        where line.includes(message)
        select line;
    test:assertEquals(lines.length(), 1, message);
    test:assertTrue(lines[0].includes(expected), lines[0]);
}

function loggedErrors() returns [string, function (error err) returns Error?, string][] => [
    ["list failed", err => toListError(err, "Employee"), "entity=\"Employee\" operation=\"get many\""],
    ["related failed", err => toListError(err, "Employee", "get related"),
        "entity=\"Employee\" operation=\"get related\""],
    ["get failed", err => toGetError(err, "Employee", [1]), "entity=\"Employee\" operation=\"get one\""],
    ["create failed", err => toCreateError(err, "Employee"), "entity=\"Employee\" operation=\"create\""],
    ["update failed", err => toUpdateError(err, "Employee", [1]),
        "entity=\"Employee\" operation=\"patch one\""],
    ["delete failed", err => toDeleteError(err, "Employee", [1]),
        "entity=\"Employee\" operation=\"delete one\""]
];

@test:Config
function testReadBackIsLoggedWithoutAnError() returns error? {
    test:assertTrue(toUpdateError(error persist:ReadBackError("read back failed"), "Employee", [1]) is ());
    string[] lines = from string line in check io:fileReadLines("target/errors_test.log")
        where line.includes("read back failed")
        select line;
    test:assertEquals(lines.length(), 1);
    test:assertTrue(lines[0].includes("entity=\"Employee\" operation=\"patch one\""), lines[0]);
}

@test:Config
function testInternalErrorHidesTheCause() {
    Error err = toListError(error persist:Error("jdbc:h2 Table \"EMPLOYEE\" not found"), "Employee");
    test:assertEquals(err.message(), "An internal error occurred.");
    test:assertFalse(err.detail().toString().includes("jdbc"));
}
