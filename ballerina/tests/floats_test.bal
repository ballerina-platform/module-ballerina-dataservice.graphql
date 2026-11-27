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
function testCheckFinite() {
    test:assertEquals(checkFinite(1.5, "Reading", "ratio"), ());
    foreach float value in [float:NaN, float:Infinity, -float:Infinity] {
        Error? err = checkFinite(value, "Reading", "ratio");
        if err is () {
            test:assertFail(value.toString());
        }
        test:assertEquals(err.detail(), {
            message: "The field 'ratio' of the entity 'Reading' is not a finite number.",
            extensions: {code: "INVALID_INPUT"}
        });
    }
}

@test:Config
function testToFinite() {
    test:assertEquals(toFinite(2.25, "Reading", "ratio"), 2.25);
    float|Error stored = toFinite(float:NaN, "Reading", "ratio");
    if stored !is Error {
        test:assertFail("NaN");
    }
    test:assertEquals(stored.detail(), {
        message: "The field 'ratio' of the entity 'Reading' holds a value that is not a finite number.",
        extensions: {code: "INTERNAL"}
    });
}
