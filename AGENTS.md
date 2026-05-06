# Instructions for AI Agents

## What is This Codebase?

This is a Zig client for the [RabbitMQ HTTP API](https://www.rabbitmq.com/docs/management).
It is modeled after [its Rust](https://github.com/michaelklishin/rabbitmq-http-api-client-rs) and [Swift 6](https://github.com/michaelklishin/rabbitmq-http-api-client-swift) counterparts.


## Build and Test

```bash
zig build

# Unit tests + pure (do not need a local RabbitMQ node) property tests
zig build test

# Everything above plus integration and property tests that do need a local RabbitMQ node
zig build integration-test
```

### Test Node Configuration

The integration tests require a RabbitMQ node with the management plugin
enabled on `localhost:15672` with default credentials.

The `test` step does not need a local RabbitMQ node.


## Repository Layout

 * `src/client.zig`: `Client` struct, HTTP request helpers
 * `src/responses.zig`: response model structs
 * `src/requests.zig`: request parameter structs
 * `src/commons.zig`: shared enums (ExchangeType, QueueType, PolicyTarget, etc.)
 * `src/builders.zig`: fluent builders (XArgumentsBuilder, PolicyDefinitionBuilder)
 * `src/root.zig`: public API exports
 * `tests/`: integration tests
 * `tests/*_prop_test.zig`: property-based tests built on
   [`proptest-zig`](https://github.com/michaelklishin/proptest-zig)
 * Pure property tests (no broker required) run under `zig build test`
 * Broker-driven property tests run under `zig build integration-test`
   alongside the regular integration tests


## Code Style

 * Target Zig 0.16.x
 * Naming: `camelCase` for functions, `PascalCase` for types, `snake_case` for files
 * Only add comments that explain *why*, not *what*
 * Do not add doc comments that restate the function name
 * Do not add section separator banners
 * Comments go above the line being commented on, not at the end

## Git Instructions

 * Do not commit changes automatically without explicit permission
 * Never add yourself to the list of commit co-authors
 * Never mention yourself in commit messages
