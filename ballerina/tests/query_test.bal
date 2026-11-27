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

final dataservice:Entity employee = {
    name: "Employee",
    collection: "employees",
    'resource: "employees",
    datastore: dataservice:H2,
    fields: [
        {name: "id", column: "id", 'type: dataservice:INT, key: true},
        {name: "name", column: "name", 'type: dataservice:STRING},
        {name: "email", column: "email", 'type: dataservice:STRING, nullable: true},
        {name: "hiredOn", column: "hiredOn", 'type: dataservice:DATE}
    ]
};

final dataservice:PageConfig page = check dataservice:toPageConfig(2, 3);

type EmployeeFilter record {|
    IntFilter? id;
    StringNullableFilter? email;
    DateFilter? hiredOn;
|};

type EmployeeSort record {|
    SortDirection? id;
    SortDirection? name;
|};

@test:Config
function testNullOperatorsSetNoCondition() returns error? {
    EmployeeFilter filter = {id: {eq: (), ne: (), lt: (), lte: (), gt: (), gte: (), anyOf: ()}, email: (), hiredOn: ()};
    dataservice:Query query = check toQuery(employee, page, filter, (), (), ());
    dataservice:Query unfiltered = check toQuery(employee, page, (), (), (), ());
    test:assertEquals(clauses(query), clauses(unfiltered));
}

@test:Config
function testFilterAndSortBuildTheQuery() returns error? {
    EmployeeFilter filter = {
        id: {eq: (), ne: (), lt: 10, lte: (), gt: (), gte: 2, anyOf: ()},
        email: {eq: (), ne: (), lt: (), lte: (), gt: (), gte: (), anyOf: (), contains: (), startsWith: (), isNull: true},
        hiredOn: ()
    };
    EmployeeSort[] sort = [{id: (), name: DESC}];
    dataservice:Query query = check toQuery(employee, page, filter, sort, 5, 1);
    dataservice:Query|dataservice:DataserviceError|dataservice:ConversionError expected =
        dataservice:toQuery(employee, page, {id: {lt: 10, gte: 2}, email: {isNull: true}}, ["-name"], 5, 1);
    if expected !is dataservice:Query {
        test:assertFail("the expected query");
    }
    test:assertEquals(clauses(query), clauses(expected));
    test:assertEquals(query.size, 3);
}

@test:Config
function testSortEntryNamesOneField() {
    EmployeeSort[][] invalid = [[{id: (), name: ()}], [{id: ASC, name: DESC}]];
    foreach EmployeeSort[] sort in invalid {
        dataservice:Query|Error query = toQuery(employee, page, (), sort, (), ());
        test:assertTrue(query is Error);
        if query is Error {
            test:assertEquals(query.detail(), {
                message: "Each entry of 'sort' must name exactly one field.",
                extensions: {code: "INVALID_INPUT"}
            });
        }
    }
}

@test:Config
function testInvalidOptionsAreInvalidInput() {
    [record {}[]?, int?, int?, string][] cases = [
        [<EmployeeSort[]>[{id: ASC, name: ()}, {id: DESC, name: ()}], (), (), "The field 'id' is named more than once in 'sort'."],
        [(), 0, (), "The page size must be at least 1."],
        [(), (), -1, "The offset must be at least 0."]
    ];
    foreach [record {}[]?, int?, int?, string] [sort, size, offset, message] in cases {
        dataservice:Query|Error query = toQuery(employee, page, (), sort, size, offset);
        if query !is Error {
            test:assertFail(message);
        }
        test:assertEquals(query.detail(), {message, extensions: {code: "INVALID_INPUT"}});
    }
}

@test:Config
function testDateThatDoesNotParse() {
    EmployeeFilter filter = {id: (), email: (), hiredOn: {eq: "01/02/2024", ne: (), lt: (), lte: (), gt: (), gte: (), anyOf: ()}};
    dataservice:Query|Error query = toQuery(employee, page, filter, (), (), ());
    if query !is Error {
        test:assertFail("a date that does not parse");
    }
    test:assertEquals(query.detail(), {
        message: "The field 'hiredOn' of the entity 'Employee' is not an ISO 8601 date.",
        extensions: {code: "INVALID_INPUT"}
    });
}

function clauses(dataservice:Query query) returns anydata[] =>
    from var clause in [query.whereClause, query.orderByClause, query.limitClause, query.offsetClause]
    select [clause.strings, clause.insertions.toString()];
