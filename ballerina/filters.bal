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

// Every operator is `T? op;`: GraphQL's nullable `T`, which a client may leave out or send as `null`, and both bind as
// `()`, meaning no condition. An optional `T op?` is published as `T` too, and ballerina/graphql cannot bind a `null`
// for it (ballerina-library#9740).

# The conditions on a `int` field; every condition set must hold.
public type IntFilter record {|
    # Equal to the value
    int? eq;
    # Not equal to the value
    int? ne;
    # Less than the value
    int? lt;
    # At most the value
    int? lte;
    # Greater than the value
    int? gt;
    # At least the value
    int? gte;
    # Equal to any of the values
    int[]? anyOf;
|};

# The conditions on a nullable `int` field. A null field matches only `isNull`.
public type IntNullableFilter record {|
    # Equal to the value
    int? eq;
    # Not equal to the value; a null field does not match
    int? ne;
    # Less than the value
    int? lt;
    # At most the value
    int? lte;
    # Greater than the value
    int? gt;
    # At least the value
    int? gte;
    # Equal to any of the values
    int[]? anyOf;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The conditions on a `float` field; every condition set must hold.
public type FloatFilter record {|
    # Equal to the value
    float? eq;
    # Not equal to the value
    float? ne;
    # Less than the value
    float? lt;
    # At most the value
    float? lte;
    # Greater than the value
    float? gt;
    # At least the value
    float? gte;
    # Equal to any of the values
    float[]? anyOf;
|};

# The conditions on a nullable `float` field. A null field matches only `isNull`.
public type FloatNullableFilter record {|
    # Equal to the value
    float? eq;
    # Not equal to the value; a null field does not match
    float? ne;
    # Less than the value
    float? lt;
    # At most the value
    float? lte;
    # Greater than the value
    float? gt;
    # At least the value
    float? gte;
    # Equal to any of the values
    float[]? anyOf;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The conditions on a `decimal` field; every condition set must hold.
public type DecimalFilter record {|
    # Equal to the value
    decimal? eq;
    # Not equal to the value
    decimal? ne;
    # Less than the value
    decimal? lt;
    # At most the value
    decimal? lte;
    # Greater than the value
    decimal? gt;
    # At least the value
    decimal? gte;
    # Equal to any of the values
    decimal[]? anyOf;
|};

# The conditions on a nullable `decimal` field. A null field matches only `isNull`.
public type DecimalNullableFilter record {|
    # Equal to the value
    decimal? eq;
    # Not equal to the value; a null field does not match
    decimal? ne;
    # Less than the value
    decimal? lt;
    # At most the value
    decimal? lte;
    # Greater than the value
    decimal? gt;
    # At least the value
    decimal? gte;
    # Equal to any of the values
    decimal[]? anyOf;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The conditions on a `string` field; every condition set must hold.
public type StringFilter record {|
    # Equal to the value
    string? eq;
    # Not equal to the value
    string? ne;
    # Less than the value
    string? lt;
    # At most the value
    string? lte;
    # Greater than the value
    string? gt;
    # At least the value
    string? gte;
    # Equal to any of the values
    string[]? anyOf;
    # Contains the value, following the database's collation
    string? contains;
    # Starts with the value, following the database's collation
    string? startsWith;
|};

# The conditions on a nullable `string` field. A null field matches only `isNull`.
public type StringNullableFilter record {|
    # Equal to the value
    string? eq;
    # Not equal to the value; a null field does not match
    string? ne;
    # Less than the value
    string? lt;
    # At most the value
    string? lte;
    # Greater than the value
    string? gt;
    # At least the value
    string? gte;
    # Equal to any of the values
    string[]? anyOf;
    # Contains the value, following the database's collation
    string? contains;
    # Starts with the value, following the database's collation
    string? startsWith;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The conditions on a `boolean` field; every condition set must hold.
public type BooleanFilter record {|
    # Equal to the value
    boolean? eq;
    # Not equal to the value
    boolean? ne;
    # Equal to any of the values
    boolean[]? anyOf;
|};

# The conditions on a nullable `boolean` field. A null field matches only `isNull`.
public type BooleanNullableFilter record {|
    # Equal to the value
    boolean? eq;
    # Not equal to the value; a null field does not match
    boolean? ne;
    # Equal to any of the values
    boolean[]? anyOf;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The conditions on a `time:Date` field, as ISO 8601 dates; every condition set must hold.
public type DateFilter record {|
    # Equal to the date
    string? eq;
    # Not equal to the date
    string? ne;
    # Less than the date
    string? lt;
    # At most the date
    string? lte;
    # Greater than the date
    string? gt;
    # At least the date
    string? gte;
    # Equal to any of the dates
    string[]? anyOf;
|};

# The conditions on a nullable `time:Date` field, as ISO 8601 dates. A null field matches only `isNull`.
public type DateNullableFilter record {|
    # Equal to the date
    string? eq;
    # Not equal to the date; a null field does not match
    string? ne;
    # Less than the date
    string? lt;
    # At most the date
    string? lte;
    # Greater than the date
    string? gt;
    # At least the date
    string? gte;
    # Equal to any of the dates
    string[]? anyOf;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The conditions on a `time:TimeOfDay` field, as ISO 8601 times; every condition set must hold.
public type TimeOfDayFilter record {|
    # Equal to the time
    string? eq;
    # Not equal to the time
    string? ne;
    # Less than the time
    string? lt;
    # At most the time
    string? lte;
    # Greater than the time
    string? gt;
    # At least the time
    string? gte;
    # Equal to any of the times
    string[]? anyOf;
|};

# The conditions on a nullable `time:TimeOfDay` field, as ISO 8601 times. A null field matches only `isNull`.
public type TimeOfDayNullableFilter record {|
    # Equal to the time
    string? eq;
    # Not equal to the time; a null field does not match
    string? ne;
    # Less than the time
    string? lt;
    # At most the time
    string? lte;
    # Greater than the time
    string? gt;
    # At least the time
    string? gte;
    # Equal to any of the times
    string[]? anyOf;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The conditions on a `time:Civil` field, as ISO 8601 date-times; every condition set must hold.
public type CivilFilter record {|
    # Equal to the date-time
    string? eq;
    # Not equal to the date-time
    string? ne;
    # Less than the date-time
    string? lt;
    # At most the date-time
    string? lte;
    # Greater than the date-time
    string? gt;
    # At least the date-time
    string? gte;
    # Equal to any of the date-times
    string[]? anyOf;
|};

# The conditions on a nullable `time:Civil` field, as ISO 8601 date-times. A null field matches only `isNull`.
public type CivilNullableFilter record {|
    # Equal to the date-time
    string? eq;
    # Not equal to the date-time; a null field does not match
    string? ne;
    # Less than the date-time
    string? lt;
    # At most the date-time
    string? lte;
    # Greater than the date-time
    string? gt;
    # At least the date-time
    string? gte;
    # Equal to any of the date-times
    string[]? anyOf;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The conditions on a `time:Utc` field, as ISO 8601 date-times; every condition set must hold.
public type UtcFilter record {|
    # Equal to the date-time
    string? eq;
    # Not equal to the date-time
    string? ne;
    # Less than the date-time
    string? lt;
    # At most the date-time
    string? lte;
    # Greater than the date-time
    string? gt;
    # At least the date-time
    string? gte;
    # Equal to any of the date-times
    string[]? anyOf;
|};

# The conditions on a nullable `time:Utc` field, as ISO 8601 date-times. A null field matches only `isNull`.
public type UtcNullableFilter record {|
    # Equal to the date-time
    string? eq;
    # Not equal to the date-time; a null field does not match
    string? ne;
    # Less than the date-time
    string? lt;
    # At most the date-time
    string? lte;
    # Greater than the date-time
    string? gt;
    # At least the date-time
    string? gte;
    # Equal to any of the date-times
    string[]? anyOf;
    # `true` for null, `false` for not null
    boolean? isNull;
|};

# The direction of a sort entry.
public enum SortDirection {
    # Ascending, nulls last
    ASC,
    # Descending, nulls first
    DESC
}
