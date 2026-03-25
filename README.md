# rabbitmq-http-api-client-zig

A Zig client for the [RabbitMQ management HTTP API](https://www.rabbitmq.com/docs/management).

Modeled after [rabbitmq-http-api-client-rs](https://github.com/michaelklishin/rabbitmq-http-api-client-rs) (Rust).


## Quick Start

```zig
const api = @import("rabbitmq_http_api_client");

var client = try api.Client.init(allocator, .{});
defer client.deinit();

const overview = try client.getOverview();
defer overview.deinit();
std.debug.print("RabbitMQ {s}\n", .{overview.value.rabbitmq_version.?});

const healthy = try client.healthCheck();
std.debug.print("Healthy: {}\n", .{healthy});
```


## Closing Connections

```zig
// Close a specific connection by name
try client.closeConnection("127.0.0.1:52345 -> 127.0.0.1:5672", "test cleanup", false);

// Close all connections for a user (idempotent)
try client.closeUserConnections("guest", "test cleanup", true);
```


## Listing Resources

```zig
const conns = try client.listConnections();
defer conns.deinit();
for (conns.value) |c| {
    std.debug.print("{s}\n", .{c.name});
}

const queues = try client.listQueues();
defer queues.deinit();

const vhosts = try client.listVhosts();
defer vhosts.deinit();
```


## License

Dual licensed under Apache License 2.0 and MIT.
