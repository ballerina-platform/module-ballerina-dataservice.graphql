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

# Checks the filter, sort and page arguments of a list and builds its query, through `dataservice:toQuery`.
#
# + entity - The entity description
# + config - The page sizes of the data service
# + filter - The `filter` argument
# + sort - The `sort` argument, each entry naming one field
# + size - The `size` argument
# + offset - The `offset` argument
# + return - The query, or the `INVALID_INPUT` error
public isolated function toQuery(dataservice:Entity entity, dataservice:PageConfig config, record {}? filter,
        record {}[]? sort, int? size, int? offset) returns dataservice:Query|Error {
    string[]? fields = check toSortFields(sort);
    return toCheckedQuery(dataservice:toQuery(entity, config, toConditions(filter), fields, size, offset),
            entity.name);
}

# Checks the filter, sort and page arguments of a to-many relation and builds the query of one record's related
# records, through `dataservice:toRelatedQuery`.
#
# + entity - The entity description of the record
# + relation - The relation field
# + row - The record, holding at least the fields that link the relation
# + config - The page sizes of the data service
# + filter - The `filter` argument
# + sort - The `sort` argument, each entry naming one field
# + size - The `size` argument
# + offset - The `offset` argument
# + return - The query, or the `INVALID_INPUT` error
public isolated function toRelatedQuery(dataservice:Entity entity, string relation, map<anydata> row,
        dataservice:PageConfig config, record {}? filter, record {}[]? sort, int? size, int? offset)
        returns dataservice:Query|Error {
    string[]? fields = check toSortFields(sort);
    string target = from dataservice:Relation related in entity.relations
        where related.'field == relation
        select related.target.name;
    return toCheckedQuery(dataservice:toRelatedQuery(entity, relation, row, config, toConditions(filter), fields,
            size, offset), target);
}

# Puts the related records of a dataloader batch in the order of its links.
#
# + rows - The related records, as `dataservice:toIncludeQuery` read them
# + entity - The entity description of the records that hold the relation
# + relation - The relation field, a to-one relation
# + links - The links of the batch: records holding the fields that link the relation
# + return - The related record of each link, or `()` for a link without one
public isolated function toKeyOrder(map<anydata>[] rows, dataservice:Entity entity, string relation,
        map<anydata>[] links) returns (map<anydata>?)[] {
    dataservice:Relation[] related = from dataservice:Relation candidate in entity.relations
        where candidate.'field == relation
        select candidate;
    if related.length() == 0 {
        panic error(string `The entity '${entity.name}' has no relation '${relation}'.`);
    }
    string[] fields = related[0].fields;
    string[] targetFields = related[0].targetFields;
    map<map<anydata>> byLink = {};
    foreach map<anydata> row in rows {
        byLink[linkText(from string name in targetFields select row[name])] = row;
    }
    return from map<anydata> link in links
        select byLink[linkText(from string name in fields select link[name])];
}

// The text form of a link, as a key of a map; `toJsonString` keeps a string's quotes, so `1` and `"1"` differ.
isolated function linkText(anydata[] values) returns string => values.toJsonString();

isolated function toCheckedQuery(dataservice:Query|dataservice:DataserviceError|dataservice:ConversionError query,
        string entity) returns dataservice:Query|Error {
    if query is dataservice:DataserviceError {
        return toError(query);
    }
    if query is dataservice:ConversionError {
        return toInvalidInput(query, entity, query.detail().'field ?: "");
    }
    return query;
}

// An operator or a field that is `()`, left out or sent as `null`, sets no condition.
isolated function toConditions(record {}? filter) returns map<map<anydata>>? {
    if filter is () {
        return ();
    }
    map<map<anydata>> conditions = {};
    foreach [string, anydata] [fieldName, operators] in filter.entries() {
        if operators !is map<anydata> {
            continue;
        }
        map<anydata> set = map from [string, anydata] [operator, value] in operators.entries()
            where value !is ()
            select [operator, value];
        if set.length() > 0 {
            conditions[fieldName] = set;
        }
    }
    return conditions;
}

// `dataservice:toQuery` takes the sort fields as names, a descending one starting with `-`.
isolated function toSortFields(record {}[]? sort) returns string[]?|Error {
    if sort is () {
        return ();
    }
    string[] fields = [];
    foreach record {} entry in sort {
        string[] named = from [string, anydata] [fieldName, direction] in entry.entries()
            where direction !is ()
            select direction == DESC ? "-" + fieldName : fieldName;
        if named.length() != 1 {
            return toError({
                code: dataservice:INVALID_INPUT,
                message: "Each entry of 'sort' must name exactly one field."
            });
        }
        fields.push(named[0]);
    }
    return fields;
}
