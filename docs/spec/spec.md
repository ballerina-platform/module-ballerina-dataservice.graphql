# Specification: Ballerina Data Service GraphQL Library

_Owners_: @niveathika  
_Reviewers_: @daneshk  
_Created_: 2026/11/18  
_Updated_: 2026/11/18  
_Edition_: Swan Lake

## Introduction

This is the specification for the `ballerina/dataservice.graphql` package of the [Ballerina language](https://ballerina.io/). The package is the GraphQL runtime of the data services that `bal persist` generates when `options.dataservice.protocol = "graphql"`. The generated service is specified in the [persist tool specification](https://github.com/ballerina-platform/persist-tools/blob/main/docs/spec/spec.md#98-graphql-service), and the protocol-neutral runtime in the [`ballerina/dataservice` specification](https://github.com/ballerina-platform/module-ballerina-dataservice/blob/main/docs/spec/spec.md).

The conforming implementation of the specification is released and included in the distribution. Any deviation from the specification is considered a bug.

### Notation

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT, RECOMMENDED, MAY and OPTIONAL are interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) and [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174) when, and only when, they appear in all capitals. Sentences that state behaviour in the present tense are also normative. The overview, notes and examples are informative.

## Contents

- [1. Overview](#1-overview)
- [2. Terminology](#2-terminology)
- [3. Errors](#3-errors)
    - [3.1. Description](#31-description)
    - [3.2. Error type](#32-error-type)
    - [3.3. Behaviour](#33-behaviour)
    - [3.4. Errors raised by ballerina/graphql](#34-errors-raised-by-ballerinagraphql)
- [4. Configuration](#4-configuration)
    - [4.1. Description](#41-description)
    - [4.2. Configuration](#42-configuration)
    - [4.3. Behaviour](#43-behaviour)
- [5. Queries](#5-queries)
    - [5.1. Description](#51-description)
    - [5.2. Filter and sort inputs](#52-filter-and-sort-inputs)
    - [5.3. Behaviour](#53-behaviour)
- [6. Floating-point values](#6-floating-point-values)
- [7. Auth](#7-auth)
    - [7.1. Description](#71-description)
    - [7.2. Behaviour](#72-behaviour)
    - [7.3. Errors](#73-errors)
- [8. Security considerations](#8-security-considerations)
- [References](#references)

## 1. Overview

A generated GraphQL data service imports this package as `dsGraphql`. It calls the functions of this package to build the queries of its lists and relations, to map errors to GraphQL errors, to check values, query limits and auth, so a fix to one of them is released without regenerating the service. The filter and sort input types of every service, and its runtime settings, are types of this package.

The functions that generated code calls are a stable API. New behaviour is added through new functions or optional parameters.

The package depends on `ballerina/dataservice` and `ballerina/graphql`, and not on `ballerina/dataservice.http`. Where this package and `ballerina/dataservice.http` behave the same, such as the provider handling of the authenticator and the per-operation error functions, the code is duplicated, so that one protocol package does not import another.

## 2. Terminology

This specification uses the terms of the [`ballerina/dataservice` specification](https://github.com/ballerina-platform/module-ballerina-dataservice/blob/main/docs/spec/spec.md#2-terminology), and these:

- **Root field:** a field of the service's `Query` or `Mutation` type, a resource or remote function of the generated service.
- **Field error:** an entry of a response's `errors` array for a field that failed. The field is `null` and the other fields keep their data.
- **Request error:** an error for which `ballerina/graphql` answers the request with no `data`.
- **Link:** a record of the fields of a record that link a relation, such as `{"employeeId": 1}`, the key of a to-one relation's dataloader.
- **Provider:** a `graphql:ListenerAuthConfig`, one entry of the service's authentication providers.

## 3. Errors

### 3.1. Description

Each error category of `ballerina/dataservice` is a field error whose `extensions.code` is the category's code, and whose `message` is the message of `ballerina/dataservice`.

### 3.2. Error type

```ballerina
public type Error distinct graphql:ServiceError;
```

`Error` is a `graphql:ServiceError`, whose detail is a `graphql:ErrorDetail`. Its detail holds the error's `message` and `extensions: {code: <ErrorCode>}`, and `ballerina/graphql` copies the extensions into the error's entry:

```json
{
  "errors": [{
    "message": "A record with the key '99' does not exist for the entity 'Employee'.",
    "locations": [{"line": 1, "column": 3}],
    "path": ["employee"],
    "extensions": {"code": "NOT_FOUND"}
  }],
  "data": {"employee": null}
}
```

### 3.3. Behaviour

| Function | Used for | Codes |
|---|---|---|
| `toListError(error err, string entity, string operation = "get many") returns Error` | Reading many records, and the related records of a relation | `INTERNAL` |
| `toGetError(error err, string entity, dataservice:KeyValue[] key, string operation = "get one") returns Error` | Reading one record | `NOT_FOUND`, `INTERNAL` |
| `toCreateError(error err, string entity) returns Error` | Creating records, and reading the created records back | `CONFLICT`, `CONSTRAINT_VIOLATION`, `INTERNAL` |
| `toUpdateError(error err, string entity, dataservice:KeyValue[] key) returns Error?` | Updating a record | `NOT_FOUND`, `CONFLICT`, `CONSTRAINT_VIOLATION`, `INTERNAL`, or `()` |
| `toDeleteError(error err, string entity, dataservice:KeyValue[] key) returns Error` | Deleting a record | `NOT_FOUND`, `CONSTRAINT_VIOLATION`, `INTERNAL` |
| `toInvalidInput(dataservice:ConversionError err, string entity, string 'field) returns Error` | A value that does not parse | `INVALID_INPUT` |
| `toNullError(string entity, string 'field) returns Error` | `null` on an input field that cannot hold it | `INVALID_INPUT` |
| `toError(dataservice:DataserviceError body) returns Error` | An error body of `ballerina/dataservice`, such as from `dataservice:checkCreateSize`, `dataservice:checkConstraints` or `dataservice:checkFiniteKey` | The body's code |

1. Each per-operation function maps the persist error with `dataservice:toErrorBody`, given the entity's name, the operation's name and, where the operation has one, the record's key. An error whose category is not among an operation's codes is the `INTERNAL` error, and is logged.
2. `toUpdateError` returns `()` for a `persist:ReadBackError`, an update that is saved but cannot be read back, and logs it. The generated patch then returns `null` with no field error.
3. `toInvalidInput` builds the message `The field '<field>' of the entity '<Entity>' is not <format>.`, where `<format>` is the `format` of the conversion error: `an ISO 8601 date`, `an ISO 8601 time`, `an ISO 8601 date-time` or `a base64 string`.
4. `toNullError` builds the message `The field '<field>' of the entity '<Entity>' cannot be null.`
5. As `dataservice:toErrorBody` defines, the detail of a constraint violation or an internal error is logged and not returned to the caller.
6. The error is logged once, with the entity's name and the operation's name. The operation is `get many` for `toListError`, `get one` for `toGetError`, `create`, `patch one` and `delete one`. A relation passes `get related` to `toListError`.

### 3.4. Errors raised by ballerina/graphql

A document that `ballerina/graphql` rejects before a resolver runs, such as a syntax error, an unknown field, argument or input field, a value of the wrong type, a missing required argument, or a document beyond the depth or complexity limit, is a request error. `ballerina/graphql` answers it with `400`, no `data` and its own message, without `extensions`. The service does not change these errors.

## 4. Configuration

### 4.1. Description

A generated service declares its runtime settings as one configurable record, `dataserviceConfig`, of a configuration type of this package. The user sets it in the `[dataserviceConfig]` table of `Config.toml`. The layout is that of `ballerina/dataservice.http`, so a table written for an HTTP data service means the same here, apart from the query limits.

### 4.2. Configuration

`Config` includes `dataservice:Config`, which holds `port`, `pageSize` and `maxPageSize`, and adds these fields:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `listenerConfig` | `graphql:ListenerConfiguration` | `{}` | The settings of the service's listener. |
| `serviceConfig` | `ServiceConfig` | `{}` | The settings of the service. |

`ServiceConfig` has these fields:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `cors` | `graphql:CorsConfig` | `{}` | The service's CORS settings. The default allows no cross-origin request. |
| `maxQueryDepth` | `int` | `15` | The deepest document the service runs. |
| `maxQueryComplexity` | `int` | `100` | The largest complexity of a document the service runs. A field counts `1`, and a to-many relation field `20`. |

`AuthConfig`, for a service with auth, has the fields of `Config`, except that `serviceConfig` is an `AuthServiceConfig` and is required. `AuthServiceConfig` includes `ServiceConfig` and adds:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `auth` | `graphql:ListenerAuthConfig[]` | Required | The service's authentication providers. It must hold at least one provider. |

### 4.3. Behaviour

1. A generated service without auth declares `configurable dsGraphql:Config dataserviceConfig = {};`, so every field has its default.
2. A generated service with auth declares `configurable dsGraphql:AuthConfig dataserviceConfig = ?;`, so the program does not start without the providers.
3. `checkLimits(ServiceConfig|AuthServiceConfig config) returns error?` returns an error when `maxQueryDepth` or `maxQueryComplexity` is below 1, with the message `The configurable value 'dataserviceConfig.serviceConfig.<limit>' must be at least 1, found <value>.` The service's `init` calls it, so a limit out of range stops the program. `ballerina/graphql` takes a complexity of `0` as no limit, which the check does not allow.
4. `graphql:ListenerConfiguration`, `graphql:CorsConfig` and `graphql:ListenerAuthConfig` have the fields of their `ballerina/http` counterparts.

## 5. Queries

### 5.1. Description

The `filter` and `sort` arguments of a list and of a to-many relation are input types of the generated service, whose fields are the input types of this package. `toQuery` and `toRelatedQuery` turn the arguments into the `dataservice:Query` of the persist client call. `toKeyOrder` orders the related records of a to-one relation's dataloader batch.

### 5.2. Filter and sort inputs

| Input type | Field type | Operators |
|---|---|---|
| `IntFilter`, `FloatFilter`, `DecimalFilter` | `int`, `float`, `decimal` | `eq`, `ne`, `lt`, `lte`, `gt`, `gte`, `anyOf` |
| `StringFilter` | `string` | `eq`, `ne`, `lt`, `lte`, `gt`, `gte`, `anyOf`, `contains`, `startsWith` |
| `BooleanFilter` | `boolean` | `eq`, `ne`, `anyOf` |
| `DateFilter`, `TimeOfDayFilter`, `CivilFilter`, `UtcFilter` | `time:Date`, `time:TimeOfDay`, `time:Civil`, `time:Utc` | `eq`, `ne`, `lt`, `lte`, `gt`, `gte`, `anyOf`, as ISO 8601 strings |

Each has a `Nullable` variant for a nullable field, such as `StringNullableFilter`, which adds `isNull`, `true` for a null field and `false` for a non-null one. Every operator is a nullable field, `T? op;`, so an operator left out and one set to `null` both mean no condition. An enum's filter, `<Enum>Filter`, is generated in the service's module.

`SortDirection` has the members `ASC`, ascending with nulls last, and `DESC`, descending with nulls first.

### 5.3. Behaviour

1. `toQuery(dataservice:Entity entity, dataservice:PageConfig config, record {}? filter, record {}[]? sort, int? size, int? offset) returns dataservice:Query|Error` builds the query of a list through `dataservice:toQuery`. `toRelatedQuery(dataservice:Entity entity, string relation, map<anydata> row, dataservice:PageConfig config, record {}? filter, record {}[]? sort, int? size, int? offset) returns dataservice:Query|Error` builds the query of the related records of one record through `dataservice:toRelatedQuery`.
2. A filter field or operator that is `()` sets no condition, and a field whose operators are all `()` sets none.
3. Each `sort` entry must set exactly one field; otherwise the function returns the `INVALID_INPUT` error `Each entry of 'sort' must name exactly one field.` A field set to `DESC` sorts descending.
4. An option that `ballerina/dataservice` rejects, such as a field named twice in `sort`, a `size` below 1 or an `offset` below 0, is the `INVALID_INPUT` error with its message. A filter value that does not parse is the error of `toInvalidInput`, naming the field and, for a relation, the related entity.
5. `toKeyOrder(map<anydata>[] rows, dataservice:Entity entity, string relation, map<anydata>[] links) returns (map<anydata>?)[]` returns, for each link in order, the row of `rows` whose fields named by the relation's `targetFields` equal the link's fields named by its `fields`, or `()` when there is none. Values are compared by their JSON form, so the string `"1"` and the number `1` differ. It panics when the entity has no such relation.

## 6. Floating-point values

1. `checkFinite(float value, string entity, string 'field) returns Error?` returns the `INVALID_INPUT` error `The field '<field>' of the entity '<Entity>' is not a finite number.` for an input `float` that is `NaN` or infinite. `ballerina/graphql` takes a literal beyond the largest `float`, such as `1e400`, as `Infinity`.
2. `toFinite(float value, string entity, string 'field) returns float|Error` returns a stored `float`, or the `INTERNAL` error `The field '<field>' of the entity '<Entity>' holds a value that is not a finite number.` when it is `NaN` or infinite, which JSON cannot hold. The error is logged.

## 7. Auth

### 7.1. Description

A data service with auth authenticates each request with `Authenticator` in the service's `contextInit`, which `ballerina/graphql` runs before it parses and validates the document, and checks scopes at the top of each root field. `ballerina/graphql` declarative auth is not used, because it answers with its own messages, checks one list of scopes for the whole service, and does not pass the caller to the resolvers.

### 7.2. Behaviour

1. `Authenticator.init(graphql:ListenerAuthConfig[] providers) returns error?` creates the listener auth handler of each provider: `http:ListenerFileUserStoreBasicAuthHandler`, `http:ListenerLdapUserStoreBasicAuthHandler`, `http:ListenerJwtAuthHandler` or `http:ListenerOAuth2Handler`.
2. `Authenticator.authenticate(graphql:Context ctx, http:Request request) returns graphql:AuthnError|graphql:AuthzError?`:
    1. Returns a `graphql:AuthzError`, `A request to a data service with auth must use POST.`, for a request whose method is not `POST`. `ballerina/graphql` runs mutations sent with `GET`, and a browser sends saved basic auth credentials with a cross-site `GET`.
    2. Tries the handlers that take the `Authorization` header's scheme, in the order of the providers, as `ballerina/http` does: a `Basic` credential only the file and LDAP user stores, and a `Bearer` credential only the JWT and OAuth2 providers. The first handler that authenticates the credential decides.
    3. Returns a `graphql:AuthnError` with the message of `dataservice:toUnauthenticatedError` and `extensions: {code: "UNAUTHENTICATED"}` when no handler authenticates it. `ballerina/graphql` answers it with `400` and no `data`, and without a `WWW-Authenticate` header.
    4. Keeps the authenticated caller in the context otherwise.
3. `checkScopes(graphql:Context ctx, string[] scopes) returns Error?` returns the `FORBIDDEN` error of `dataservice:toNoScopeError` when the caller holds none of the scopes. Each root field calls it with the scopes of its action.
4. `hasScope(graphql:Context ctx, string[] scopes) returns boolean` returns whether the caller holds one of the scopes, and `false` without a caller. An empty list takes the deciding provider's `scopes`, and holds when the provider sets none. `checkScopes` and `checkRelationScopes` check their lists in the same way.
5. `checkRelationScopes(graphql:Context ctx, graphql:Field 'field, string entity, map<RelationScopes> relations, string[]? entityScopes = ()) returns Error?` walks the selection of the root field, through its `items` when the field returns a page, an `<Entity>List`, and through fragments, and for the first selected relation that `relations` names whose `RelationScopes.scopes` the caller holds none of, returns the `FORBIDDEN` error of `dataservice:toForbiddenError`. With `entityScopes`, which a mutation passes, a selected relation also needs one of the entity's own `read` scopes, and the caller without one gets the error of `dataservice:toNoScopeError`. The check runs once per root field, so a page has one error, not one per record. It reads only the relations of the root field's own records, one level deep, because a related record, an `<Entity>RelatedObject`, has no relation fields; a related record that has relation fields needs this walk to recurse.
6. `RelationScopes` holds `target`, the name of the related entity, and `scopes`, its `read` scopes.
7. For an OAuth2 provider, a scope is held when it is one of the whitespace-separated values of the introspection response's `scopeKey` claim, as `http:ListenerOAuth2Handler` checks it.

### 7.3. Errors

| Case | Result |
|---|---|
| The providers list is empty | `Authenticator.init` returns an error with the message `The configurable value 'dataserviceConfig.serviceConfig.auth' must hold at least one authentication provider.`, so the program stops. |
| A request that is not `POST` | `authenticate` returns `graphql:AuthzError`. |
| No handler authenticates the credential | `authenticate` returns `graphql:AuthnError`, with `UNAUTHENTICATED`. |
| The caller holds no scope of the action | `checkScopes` returns the `FORBIDDEN` error. |
| The caller may not read a selected relation | `checkRelationScopes` returns the `FORBIDDEN` error. |

## 8. Security considerations

- Every field error carries only the message and code of `ballerina/dataservice`. The persist client's error message, which can hold driver text such as table and constraint names, is never returned; it is logged.
- The default `cors` allows no cross-origin request.
- A service with auth does not start without at least one authentication provider, and refuses every request but `POST`.
- A request without a valid credential is refused before `ballerina/graphql` parses it, so neither an introspection query nor a validation error reveals the schema to an unauthenticated caller.
- A relation that needs a scope of the related entity is checked against the credential before it is read.
- The query depth and complexity limits bound the work of a document, and cannot be turned off.

## References

- [BEP 1520: Persist data service over GraphQL](https://github.com/ballerina-platform/ballerina-spec/issues/1520)
- [`ballerina/dataservice` specification](https://github.com/ballerina-platform/module-ballerina-dataservice/blob/main/docs/spec/spec.md)
- [Persist tool specification, the GraphQL service](https://github.com/ballerina-platform/persist-tools/blob/main/docs/spec/spec.md#98-graphql-service)
- [RFC 2119: Key words for use in RFCs to Indicate Requirement Levels](https://www.rfc-editor.org/rfc/rfc2119)
- [RFC 8174: Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words](https://www.rfc-editor.org/rfc/rfc8174)
