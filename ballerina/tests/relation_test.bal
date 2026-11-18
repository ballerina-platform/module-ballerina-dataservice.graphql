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
import ballerina/test;

final readonly & dataservice:Field[] departmentFields = [
    {name: "id", column: "id", 'type: dataservice:INT, key: true},
    {name: "name", column: "name", 'type: dataservice:STRING}
];

final readonly & dataservice:Field[] colleagueFields = [
    {name: "id", column: "id", 'type: dataservice:INT, key: true},
    {name: "name", column: "name", 'type: dataservice:STRING},
    {name: "departmentId", column: "departmentId", 'type: dataservice:INT}
];

final readonly & dataservice:Field[] slotFields = [
    {name: "room", column: "room", 'type: dataservice:STRING, key: true},
    {name: "seq", column: "seq", 'type: dataservice:INT, key: true}
];

final dataservice:Entity staff = {
    name: "Worker",
    collection: "workers",
    'resource: "workers",
    datastore: dataservice:H2,
    fields: [
        {name: "id", column: "id", 'type: dataservice:INT, key: true},
        {name: "departmentId", column: "departmentId", 'type: dataservice:INT},
        {name: "slotRoom", column: "slotRoom", 'type: dataservice:STRING},
        {name: "slotSeq", column: "slotSeq", 'type: dataservice:INT}
    ],
    relations: [
        {
            'field: "department",
            many: false,
            fields: ["departmentId"],
            targetFields: ["id"],
            target: {name: "Department", collection: "departments", 'resource: "departments",
                datastore: dataservice:H2, fields: departmentFields}
        },
        {
            'field: "slot",
            many: false,
            fields: ["slotRoom", "slotSeq"],
            targetFields: ["room", "seq"],
            target: {name: "Slot", collection: "slots", 'resource: "slots", datastore: dataservice:H2,
                fields: slotFields}
        },
        {
            'field: "colleagues",
            many: true,
            fields: ["departmentId"],
            targetFields: ["departmentId"],
            target: {name: "Colleague", collection: "colleagues", 'resource: "colleagues",
                datastore: dataservice:H2, fields: colleagueFields}
        }
    ]
};

@test:Config
function testKeyOrderFollowsTheLinks() {
    map<anydata>[] rows = [{id: 2, name: "Sales"}, {id: 1, name: "Research"}];
    test:assertEquals(toKeyOrder(rows, staff, "department", [{departmentId: 1}, {departmentId: 3}, {departmentId: 2}]),
            [{id: 1, name: "Research"}, (), {id: 2, name: "Sales"}]);
}

@test:Config
function testKeyOrderWithACompositeLink() {
    map<anydata>[] rows = [{room: "B", seq: 1}, {room: "A", seq: 1}];
    test:assertEquals(toKeyOrder(rows, staff, "slot", [{slotRoom: "A", slotSeq: 1}, {slotRoom: "A", slotSeq: 2}]),
            [{room: "A", seq: 1}, ()]);
}

@test:Config
function testKeyOrderTellsStringsFromNumbers() {
    map<anydata>[] rows = [{room: "1", seq: 1}];
    test:assertEquals(toKeyOrder(rows, staff, "slot", [{slotRoom: "1", slotSeq: 1}, {slotRoom: 1, slotSeq: 1}]),
            [{room: "1", seq: 1}, ()]);
}

@test:Config
function testRelatedQueryNamesTheRelatedEntity() {
    record {|IntFilter? id;|} filter = {id: ()};
    dataservice:Query|Error query = toRelatedQuery(staff, "colleagues", {departmentId: 1}, page, filter,
            [<record {|SortDirection? name;|}>{name: DESC}], 0, ());
    if query !is Error {
        test:assertFail("a size below 1");
    }
    test:assertEquals(query.detail(), {message: "The page size must be at least 1.", extensions: {code: "INVALID_INPUT"}});
}

@test:Config
function testRelatedQueryBuildsTheQuery() returns error? {
    dataservice:Query query = check toRelatedQuery(staff, "colleagues", {departmentId: 1}, page, (), (), (), ());
    dataservice:Query|dataservice:DataserviceError|dataservice:ConversionError expected =
        dataservice:toRelatedQuery(staff, "colleagues", {departmentId: 1}, page);
    if expected !is dataservice:Query {
        test:assertFail("the expected query");
    }
    test:assertEquals(clauses(query), clauses(expected));
}
