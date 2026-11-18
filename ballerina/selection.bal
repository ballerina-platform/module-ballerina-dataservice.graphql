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

// The names of the fields a document selects in the records that `field` returns: its subfields, or those of its
// `items` for a page. Fragments are already expanded in the subfields.
isolated function toSelectedNames(graphql:Field 'field) returns string[] {
    graphql:Field[] selection = subfieldsOf('field);
    graphql:Field[] items = from graphql:Field sub in selection
        where sub.getName() == "items"
        select sub;
    if items.length() > 0 {
        selection = [];
        foreach graphql:Field sub in items {
            selection.push(...subfieldsOf(sub));
        }
    }
    return from graphql:Field sub in selection
        select sub.getName();
}

// Root fields resolve concurrently, and concurrent first calls of `getSubfields` after startup can stop the program
// with a `TypeCastError` from `cloneReadOnly` inside ballerina/graphql, so the calls are serialized.
isolated function subfieldsOf(graphql:Field 'field) returns graphql:Field[] {
    lock {
        return 'field.getSubfields() ?: [];
    }
}
