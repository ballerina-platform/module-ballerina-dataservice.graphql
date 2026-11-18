# Ballerina Data Service GraphQL Library

[![Build](https://github.com/ballerina-platform/module-ballerina-dataservice.graphql/actions/workflows/build-timestamped-master.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-dataservice.graphql/actions/workflows/build-timestamped-master.yml)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerina-dataservice.graphql/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerina-dataservice.graphql)
[![Security Scan](https://github.com/ballerina-platform/module-ballerina-dataservice.graphql/actions/workflows/security-scan.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-dataservice.graphql/actions/workflows/security-scan.yml)
[![GraalVM Check](https://github.com/ballerina-platform/module-ballerina-dataservice.graphql/actions/workflows/build-with-bal-test-graalvm.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-dataservice.graphql/actions/workflows/build-with-bal-test-graalvm.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerina-dataservice.graphql.svg)](https://github.com/ballerina-platform/module-ballerina-dataservice.graphql/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/dataservice.graphql.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Fdataservice.graphql)

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

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 25. You can download it from either of the following sources:

    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Export Github Personal access token with read package permissions as follows,

    ```bash
    export packageUser=<Username>
    export packagePAT=<Personal access token>
    ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To debug the package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

5. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

6. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

7. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`dataservice.graphql` package](https://central.ballerina.io/ballerina/dataservice.graphql/latest).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
