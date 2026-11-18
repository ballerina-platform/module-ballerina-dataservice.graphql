# Ballerina Data Service GraphQL Library

## Overview

The `ballerina/dataservice.graphql` package is the GraphQL runtime of the data services that `bal persist` generates from a persist model. Generated GraphQL services call it to build their queries, map errors and check auth, so fixes reach them without regeneration.

### Key Features

- Filter and sort input types shared by every generated service, and the queries of lists and relations built from them
- GraphQL errors that carry the data service error category in `extensions.code`
- An authenticator that checks Basic, JWT and OAuth2 credentials before a document is parsed, and the scope checks of each root field and relation
- The runtime settings: port, listener, CORS, query depth and complexity limits, auth and page sizes

## Quick start

The package is used by generated code, not imported by hand. To generate a GraphQL data service:

1. Add the persist entry with a GraphQL data service to the package:

    ```bash
    bal persist add --datastore h2 --dataservice graphql
    ```

2. Annotate each entity to expose in `persist/model.bal` with `@dataservice:Expose`.

3. Build and run the package. The service is served on port `9090` under `/graphql`, with GraphiQL at `/graphiql`:

    ```bash
    bal run
    curl localhost:9090/graphql -H 'Content-Type: application/json' -d '{"query": "{ employees { items { id name } hasMore } }"}'
    ```

A field that fails is `null`, with an entry in `errors` that names the error category:

```json
{"errors": [{"message": "A record with the key '99' does not exist for the entity 'Employee'.", "path": ["employee"], "extensions": {"code": "NOT_FOUND"}}], "data": {"employee": null}}
```

For the details, see the [specification](https://github.com/ballerina-platform/module-ballerina-dataservice.graphql/blob/main/docs/spec/spec.md).
