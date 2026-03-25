# Instructions for AI Agents

## What is This Codebase?

This is a Zig HTTP API client for the [RabbitMQ management plugin](https://www.rabbitmq.com/docs/management).
It is modeled after [its Rust](https://github.com/michaelklishin/rabbitmq-http-api-client-rs) and [Swift 6](https://github.com/michaelklishin/rabbitmq-http-api-client-swift) counterparts.


## Build and Test

```bash
zig build

zig build test
```

### Test Node Configuration

Integration tests require a RabbitMQ node with the management plugin enabled
on `localhost:15672` with default credentials (`guest`/`guest`).


## Repository Layout

 * `src/client.zig`: `Client` struct, HTTP request helpers
 * `src/responses.zig`: response model structs
 * `src/requests.zig`: request parameter structs
 * `src/commons.zig`: shared enums (ExchangeType, QueueType, PolicyTarget, etc.)
 * `src/builders.zig`: fluent builders (XArgumentsBuilder, PolicyDefinitionBuilder)
 * `src/root.zig`: public API exports
 * `tests/`: integration tests


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
