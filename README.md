# A Zig Client for the RabbitMQ HTTP API

A Zig client for the [RabbitMQ management HTTP API](https://www.rabbitmq.com/docs/management).

Modeled after [rabbitmq-http-api-client-rs](https://github.com/michaelklishin/rabbitmq-http-api-client-rs)
(the Rust client). Targets Zig `0.16`.

This is **not** an AMQP 0-9-1, AMQP 1.0, or
[RabbitMQ Stream protocol](https://www.rabbitmq.com/docs/streams) client. For
publishing and consuming messages in production, use a dedicated protocol
library.


## Project Maturity

The library is functional and covers the bulk of the management API.

Before `1.0.0`, breaking API changes can and will be introduced.


## Supported RabbitMQ Series

This library targets RabbitMQ 4.x and 3.13.x. Older series have
[reached End of Life](https://www.rabbitmq.com/release-information).


## Adding the Dependency

```sh
zig fetch --save https://github.com/michaelklishin/rabbitmq-http-api-client-zig/archive/refs/tags/v0.5.0.tar.gz
```

In `build.zig`:

```zig
const rabbitmq = b.dependency("rabbitmq_http_api_client", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("rabbitmq_http_api_client", rabbitmq.module("rabbitmq_http_api_client"));
```

The examples below import the package as `api`:

```zig
const api = @import("rabbitmq_http_api_client");
```


## Quick Start

```zig
const std = @import("std");
const api = @import("rabbitmq_http_api_client");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded_io: std.Io.Threaded = .init(allocator, .{});
    defer threaded_io.deinit();
    const io = threaded_io.io();

    var client = try api.Client.init(allocator, io, .{});
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    std.debug.print("RabbitMQ {s}\n", .{overview.value.rabbitmq_version.?});

    const queues = try client.listQueues();
    defer queues.deinit();
    for (queues.value) |queue| {
        std.debug.print("{s}\n", .{queue.name});
    }
}
```


## Instantiate a Client

```zig
var client = try api.Client.init(allocator, io, .{
    .endpoint = "http://rabbitmq.example.com:15672/api",
    .username = "billing-app",
    .password = "p4ssw0rd",
});
defer client.deinit();
```

`ClientOptions` defaults to `http://localhost:15672/api` with `guest:guest`,
which is convenient for local development.


## Memory Management

Read methods return `std.json.Parsed(T)`. The caller owns the parsed data and
frees it with `.deinit()`. Mutating methods return `!void` and have no parsed
result to free.

```zig
const queues = try client.listQueues();
defer queues.deinit();

for (queues.value) |queue| {
    std.debug.print("{s}\n", .{queue.name});
}
```

### Argument and Definition Maps

Queue arguments and policy definitions are JSON objects. Build them with
`std.json.ObjectMap`:

```zig
var args: std.json.ObjectMap = .empty;
defer args.deinit(allocator);
try args.put(allocator, "x-max-length", .{ .integer = 10_000 });
```

`ObjectMap` is unmanaged in Zig 0.16, so the allocator is passed explicitly to
`put` and `deinit`. For type-safe alternatives, see
[`XArgumentsBuilder`](#type-safe-queue-arguments) and
[`PolicyDefinitionBuilder`](#policy-operations).


## Reachability Probe

`probeReachability` checks whether the node is reachable and that
authentication succeeds. It returns `ReachabilityProbeOutcome`, not an error
union, because both outcomes are expected:

```zig
const outcome = client.probeReachability();
if (outcome.successful) {
    std.debug.print("connected\n", .{});
} else {
    std.debug.print("unreachable\n", .{});
}
```


## Idempotent Operations

`delete*` and `clear*` methods take an `idempotent: bool` argument. When
`true`, missing resources do not produce an error:

```zig
// Succeeds even though the queue does not exist
try client.deleteQueue("/", "missing.queue", true);

// Returns error.NotFound
try client.deleteQueue("/", "missing.queue", false);
```


## Error Handling

Methods return Zig error unions. The most common variants:

| Error                | Meaning                                        |
| -------------------- | ---------------------------------------------- |
| `error.NotFound`     | 404 — resource does not exist                  |
| `error.Unauthorized` | 401 — credentials rejected                     |
| `error.Forbidden`    | 403 — credentials lack the required permission |
| `error.BadRequest`   | 400 — request rejected by the broker           |
| `error.Conflict`     | 409 — resource state conflict                  |
| `error.ServerError`  | 5xx — broker error                             |

Catch a specific variant with `catch`, or with the if/else error capture form:

```zig
if (client.getQueueInfo("/", "billing.invoices")) |info| {
    defer info.deinit();
    std.debug.print("{s}\n", .{info.value.name});
} else |err| switch (err) {
    error.NotFound => std.debug.print("queue does not exist\n", .{}),
    else => return err,
}
```


## Cluster Operations

### List Cluster Nodes

```zig
const nodes = try client.listNodes();
defer nodes.deinit();
for (nodes.value) |node| {
    std.debug.print("{s}\n", .{node.name});
}
```

### Cluster Name

```zig
const cluster_name = try client.getClusterName();
defer cluster_name.deinit();

try client.setClusterName("rabbit-prod");
```

### Cluster Tags

[Cluster tags](https://www.rabbitmq.com/docs/parameters#cluster-tags) are
arbitrary key-value pairs attached to a cluster:

```zig
const current_tags = try client.getClusterTags();
defer current_tags.deinit();

var tags: std.json.ObjectMap = .empty;
defer tags.deinit(allocator);
try tags.put(allocator, "environment", .{ .string = "production" });
try tags.put(allocator, "region", .{ .string = "ca-central-1" });
try client.setClusterTags(.{ .object = tags });

try client.clearClusterTags();
```

### Node Memory Footprint

```zig
const footprint = try client.getNodeMemoryFootprint("rabbit@node1.example.com");
defer footprint.deinit();
```

Returns a per-category
[memory footprint breakdown](https://www.rabbitmq.com/docs/memory-use)
in bytes. `getNodeMemoryFootprintRelative` returns the same data as
percentages.

### Rebalance Queue Leaders

Redistributes quorum queue and stream leaders across cluster nodes:

```zig
try client.rebalanceQueueLeaders();
```


## Virtual Host Operations

[Virtual hosts](https://www.rabbitmq.com/docs/vhosts) group and isolate
resources.

```zig
const vhosts = try client.listVhosts();
defer vhosts.deinit();

const vhost = try client.getVhost("/");
defer vhost.deinit();
```

### Create a Virtual Host

```zig
try client.createVhost("billing", .{
    .description = "Billing service",
    .default_queue_type = "quorum",
    .tracing = false,
});
```

Or fluently:

```zig
const params = (api.requests.VirtualHostParams{})
    .withDescription("Billing service")
    .withDefaultQueueType(.quorum);
try client.createVhost("billing", params);
```

### Delete a Virtual Host

```zig
try client.deleteVhost("billing", false);
```

`deleteVhost(name, true)` is idempotent — it does not fail when the vhost is
missing.

### Deletion Protection

```zig
try client.enableVhostDeletionProtection("billing");
try client.disableVhostDeletionProtection("billing");
```


## User Operations

```zig
const users = try client.listUsers();
defer users.deinit();

const current_user = try client.whoAmI();
defer current_user.deinit();
```

### Create a User

Plain password (the broker hashes it):

```zig
try client.createUser("billing-app", .{
    .password = "p4ssw0rd",
    .tags = "management",
});
```

Locally [salted and hashed](https://www.rabbitmq.com/docs/passwords)
(recommended in production):

```zig
const salt = try api.commons.salt(io);
const hash = api.commons.base64EncodedSaltedPasswordHashSha256(salt, "p4ssw0rd");

try client.createUser("billing-app", .{
    .password_hash = &hash,
    .hashing_algorithm = api.commons.HashingAlgorithm.sha256.toApiString(),
    .tags = "management",
});
```

`base64EncodedSaltedPasswordHashSha512` produces SHA-512 hashes. Tags accept a
comma-separated list (`"management,monitoring"`).

### Delete Users

```zig
try client.deleteUser("billing-app", false);

// Bulk delete
try client.deleteUsers(.{ .users = &.{ "test-a", "test-b", "test-c" } });
```


## Connection Operations

```zig
const connections = try client.listConnections();
defer connections.deinit();

for (connections.value) |conn| {
    std.debug.print("{s} (user={?s})\n", .{ conn.name, conn.user });
}
```

### Close Connections

```zig
const connections = try client.listConnections();
defer connections.deinit();
for (connections.value) |conn| {
    try client.closeConnection(conn.name, "node draining for maintenance", false);
}

// Close all of a user's connections
try client.closeUserConnections("billing-app", "credential rotation", true);
```


## Queue Operations

```zig
const queues = try client.listQueues();
defer queues.deinit();

const queues_in_default = try client.listQueuesByVhost("/");
defer queues_in_default.deinit();

const info = try client.getQueueInfo("/", "billing.invoices");
defer info.deinit();
```

Listing by type:

```zig
const quorum_queues = try client.listQuorumQueues();
defer quorum_queues.deinit();

const classic_queues = try client.listClassicQueuesByVhost("/");
defer classic_queues.deinit();

const streams = try client.listStreams();
defer streams.deinit();
```

### Queue Length and Other Metrics

`getQueueInfo` returns counters such as queue length (messages in Ready
state, `messages_ready`), the total number of messages (`messages`, ready +
unacknowledged), the unacknowledged count, and the consumer count:

```zig
const info = try client.getQueueInfo("/", "billing.invoices");
defer info.deinit();
const q = info.value;

std.debug.print(
    "{s}: length={?d} total={?d} unacked={?d} consumers={?d}\n",
    .{ q.name, q.messages_ready, q.messages, q.messages_unacknowledged, q.consumers },
);
```

### Declare a Classic Queue

```zig
try client.declareClassicQueue("/", "billing.invoices");
```

### Declare a Quorum Queue

[Quorum queues](https://www.rabbitmq.com/docs/quorum-queues) are replicated,
data-safety-oriented queues based on Raft.

```zig
try client.declareQuorumQueue("/", "billing.invoices");
```

### Type-Safe Queue Arguments

`XArgumentsBuilder` is a typed alternative to building a raw `ObjectMap` for
[optional queue arguments](https://www.rabbitmq.com/docs/queues#optional-arguments):

```zig
var xargs = api.builders.XArgumentsBuilder.init(allocator);
defer xargs.deinit();
const arguments = try xargs
    .maxLength(10_000)
    .deadLetterExchange("billing.dlx")
    .deadLetterStrategy(.at_least_once)
    .deliveryLimit(5)
    .singleActiveConsumer(true)
    .build();

try client.declareQueue("/", "billing.invoices", .{
    .durable = true,
    .arguments = arguments,
});
```

### Declare a Stream

[Streams](https://www.rabbitmq.com/docs/streams) are persistent, replicated
append-only logs with non-destructive consumer semantics.

```zig
try client.declareStream("/", "billing.events");

// With custom arguments
var args: std.json.ObjectMap = .empty;
defer args.deinit(allocator);
try args.put(allocator, "x-queue-type", .{ .string = "stream" });
try args.put(allocator, "x-max-length-bytes", .{ .integer = 10_000_000_000 });
try client.declareStreamWithArguments("/", "billing.events", .{ .object = args });
```

### Purge, Delete, Bulk Delete

```zig
try client.purgeQueue("/", "billing.invoices");
try client.deleteQueue("/", "billing.invoices", false);
try client.deleteQueues("/", &.{ "billing.invoices", "billing.refunds" }, false);
```

### Pagination

```zig
const page = try client.listQueuesPaged(.{ .page = 1, .page_size = 100 });
defer page.deinit();

std.debug.print("page {?d} of {?d}\n", .{ page.value.page, page.value.page_count });
for (page.value.items) |queue| {
    std.debug.print("{s}\n", .{queue.name});
}
```

Paginated variants exist for queues, exchanges, connections, channels, users,
vhosts, and streams.


## Exchange Operations

```zig
const exchanges = try client.listExchanges();
defer exchanges.deinit();
```

### Declare an Exchange

Helpers for the four built-in types:

```zig
try client.declareTopicExchange("/", "billing.events");
try client.declareFanoutExchange("/", "billing.broadcast");
try client.declareDirectExchange("/", "billing.commands");
try client.declareHeadersExchange("/", "billing.filters");
```

Or with full parameters:

```zig
try client.declareExchange("/", "billing.events", .{
    .type = "topic",
    .durable = true,
    .auto_delete = false,
    .internal = false,
});

try client.declareExchange(
    "/",
    "billing.events",
    api.requests.ExchangeParams.ofType(.topic),
);
```

### Delete an Exchange

```zig
try client.deleteExchange("/", "billing.events", false);
try client.deleteExchanges("/", &.{ "billing.events", "billing.broadcast" }, true);
```


## Binding Operations

```zig
const bindings = try client.listBindings();
defer bindings.deinit();

const queue_bindings = try client.listQueueBindings("/", "billing.invoices");
defer queue_bindings.deinit();
```

### Bind a Queue to an Exchange

```zig
try client.bindQueue("/", "billing.events", "billing.invoices", .{
    .routing_key = "invoice.#",
});
```

### Bind an Exchange to an Exchange

```zig
try client.bindExchange("/", "billing.events", "billing.archive", .{
    .routing_key = "#",
});
```

### Delete a Binding

```zig
try client.deleteBinding(.{
    .vhost = "/",
    .source = "billing.events",
    .destination = "billing.invoices",
    .destination_type = .queue,
    .properties_key = "invoice.#",
});
```


## Permission Operations

[Permissions](https://www.rabbitmq.com/docs/access-control) gate access to
resources within a vhost:

```zig
try client.grantPermissions("/", "billing-app", .{
    .configure = "^billing\\.",
    .read = ".*",
    .write = ".*",
});

try client.clearPermissions("/", "billing-app", true);
```

`PermissionParams` exposes shorthand constructors:

```zig
try client.declarePermissions("/", "billing-admin", .fullAccess());
try client.declarePermissions("/", "billing-reader", .readOnly());
try client.declarePermissions("/", "billing-no-access", .noAccess());
```

### Topic Permissions

```zig
try client.grantTopicPermissions("/", "billing-app", .{
    .exchange = "billing.events",
    .read = "^public\\.",
    .write = "^public\\.",
});
```


## Policy Operations

[Policies](https://www.rabbitmq.com/docs/policies) dynamically configure queue
and exchange properties via pattern matching.

```zig
const policies = try client.listPolicies();
defer policies.deinit();

const local_policies = try client.listPoliciesByVhost("/");
defer local_policies.deinit();
```

### Declare a Policy

`PolicyDefinitionBuilder` provides typed setters for the most common policy
keys:

```zig
var policy_def = api.builders.PolicyDefinitionBuilder.init(allocator);
defer policy_def.deinit();
const definition = try policy_def
    .maxLength(10_000)
    .deadLetterExchange("billing.dlx")
    .build();

try client.declarePolicy("/", "billing-size-limit", .{
    .pattern = "^billing\\.",
    .definition = definition,
    .priority = 10,
    .@"apply-to" = "queues",
});
```

> The `apply-to` field uses Zig's `@"name"` syntax because the wire key
> contains a hyphen.

### Delete a Policy

```zig
try client.deletePolicy("/", "billing-size-limit", false);
```

### Operator Policies

```zig
try client.declareOperatorPolicy("/", "global-throughput-cap", .{
    .pattern = "^.*$",
    .definition = definition,
    .@"apply-to" = "queues",
});
try client.deleteOperatorPolicy("/", "global-throughput-cap", true);
```


## Shovel Operations

[Dynamic shovels](https://www.rabbitmq.com/docs/shovel-dynamic) move messages
between queues, possibly across clusters:

```zig
const params = api.requests.Amqp091ShovelParams.fromQueueToQueue(
    "amqp://blue-cluster.internal:5672",
    "orders.in",
    "amqp://green-cluster.internal:5672",
    "orders.in",
);
try client.declareAmqp091Shovel("/", "orders-blue-to-green", params);

const shovels = try client.listShovels();
defer shovels.deinit();

try client.deleteShovel("/", "orders-blue-to-green", true);
```

AMQP 1.0 shovels use `declareAmqp10Shovel` with `Amqp10ShovelParams`.


## Federation Operations

[Federation](https://www.rabbitmq.com/docs/federation) replicates exchanges
and queues across clusters:

```zig
try client.declareFederationUpstreamTyped("/", "blue-cluster", .{
    .value = .{
        .uri = "amqp://blue-cluster.internal:5672",
        .@"ack-mode" = "on-confirm",
    },
});

const upstreams = try client.listFederationUpstreams();
defer upstreams.deinit();

const links = try client.listFederationLinks();
defer links.deinit();

try client.deleteFederationUpstream("/", "blue-cluster", true);
```


## Runtime Parameters

[Runtime parameters](https://www.rabbitmq.com/docs/parameters) carry per-vhost
plugin configuration (federation upstreams, shovels, vhost limits, …):

```zig
var value: std.json.ObjectMap = .empty;
defer value.deinit(allocator);
try value.put(allocator, "max-connections", .{ .integer = 500 });

try client.upsertRuntimeParameter("vhost-limits", "/", "limits", .{
    .value = .{ .object = value },
});

const all_params = try client.listRuntimeParameters();
defer all_params.deinit();

try client.deleteRuntimeParameter("vhost-limits", "/", "limits", false);
```


## Global Runtime Parameters

Cluster-wide [runtime parameters](https://www.rabbitmq.com/docs/parameters) not
scoped to a virtual host:

```zig
var tags: std.json.ObjectMap = .empty;
defer tags.deinit(allocator);
try tags.put(allocator, "region", .{ .string = "ca-central-1" });
try tags.put(allocator, "environment", .{ .string = "production" });

try client.upsertGlobalParameter("cluster_tags", .{ .value = .{ .object = tags } });

const all_globals = try client.listGlobalParameters();
defer all_globals.deinit();

try client.deleteGlobalParameter("cluster_tags", true);
```


## Virtual Host and User Limits

```zig
try client.setVhostLimit("/", .max_connections, 500);
try client.setUserLimit("billing-app", .max_connections, 100);

const vhost_limits = try client.listAllVhostLimits();
defer vhost_limits.deinit();

try client.clearVhostLimit("/", .max_connections);
try client.clearUserLimit("billing-app", .max_connections);
```


## Definitions

[Definitions](https://www.rabbitmq.com/docs/definitions) carry schema,
topology, and user metadata for export and import.

```zig
const definitions = try client.exportClusterWideDefinitions();
defer definitions.deinit();

const vhost_definitions = try client.exportVhostDefinitions("/");
defer vhost_definitions.deinit();

// As a JSON string for round-tripping
const definitions_json = try client.exportClusterWideDefinitionsAsString();
defer allocator.free(definitions_json);

try client.importClusterWideDefinitions(definitions_json);
try client.importVhostDefinitions("/", definitions_json);
```


## Health Checks

Each method returns `!bool`. An error indicates the broker reported a problem
with the check itself; a `false` return means the check ran but the condition
is not met.

```zig
_ = try client.healthCheckClusterAlarms();
_ = try client.healthCheckLocalAlarms();
_ = try client.healthCheckNodeIsQuorumCritical();
_ = try client.healthCheckPortListener(5672);
_ = try client.healthCheckProtocolListener(.amqp);
_ = try client.healthCheckIsInService();
_ = try client.healthCheckBelowConnectionLimit();
_ = try client.healthCheckQuorumQueuesWithoutLeaders();
```


## Feature Flags and Deprecated Features

[Feature flags](https://www.rabbitmq.com/docs/feature-flags) gate new
functionality that requires cluster-wide coordination.

```zig
const flags = try client.listFeatureFlags();
defer flags.deinit();

try client.enableFeatureFlag("classic_mirrored_queue_version");
try client.enableAllStableFeatureFlags();

const in_use = try client.listDeprecatedFeaturesInUse();
defer in_use.deinit();
```


## Quorum Queue Membership

```zig
const status = try client.getQuorumQueueStatus("/", "billing.invoices");
defer status.deinit();

try client.addQuorumQueueReplica("/", "billing.invoices", "rabbit@node3.example.com");
try client.deleteQuorumQueueReplica("/", "billing.invoices", "rabbit@node1.example.com");
try client.growQuorumQueueReplicas("rabbit@node3.example.com");
try client.shrinkQuorumQueueReplicas("rabbit@gone.example.com");
```


## Publishing and Consuming for Diagnostics

The HTTP API can publish a single message and pull a few messages off a queue
**for diagnostic purposes only** — not for production messaging.

```zig
const publish_result = try client.publishMessage("/", "billing.events", .{
    .routing_key = "invoice.created",
    .payload = "{\"id\":42}",
});
defer publish_result.deinit();

const messages = try client.getMessages("/", "billing.invoices", .{
    .count = 10,
    .ackmode = "ack_requeue_true",
});
defer messages.deinit();
```


## TLS

Pass an absolute path to a CA certificate bundle in the PEM format. This is
required for self-signed certificates, including those generated by `tls-gen`:

```zig
var client = try api.Client.init(allocator, io, .{
    .endpoint = "https://rabbitmq.example.com:15671/api",
    .ca_cert_file = "/etc/rabbitmq/tls/ca_certificate.pem",
});
defer client.deinit();
```


## Combined Examples

### Provision an Application Environment

Create an isolated vhost with a dedicated user, topology, and permissions:

```zig
fn provisionEnvironment(client: *api.Client, io: std.Io) !void {
    try client.createVhost("billing", .{
        .description = "Billing service",
        .default_queue_type = "quorum",
    });

    const salt = try api.commons.salt(io);
    const hash = api.commons.base64EncodedSaltedPasswordHashSha256(salt, "p4ssw0rd");
    try client.createUser("billing-app", .{
        .password_hash = &hash,
        .hashing_algorithm = api.commons.HashingAlgorithm.sha256.toApiString(),
        .tags = "",
    });

    try client.grantPermissions("billing", "billing-app", .{
        .configure = "^billing\\.",
        .read = ".*",
        .write = ".*",
    });

    try client.declareTopicExchange("billing", "billing.events");
    try client.declareQuorumQueue("billing", "billing.invoices");
    try client.bindQueue("billing", "billing.events", "billing.invoices", .{
        .routing_key = "invoice.#",
    });
}
```

### Event Topology with Dead-Lettering

Set up a topic exchange that fans events out to per-service queues, each with
its own dead-letter queue for failed messages:

```zig
fn setupEventTopology(
    client: *api.Client,
    allocator: std.mem.Allocator,
    vhost: []const u8,
) !void {
    try client.declareTopicExchange(vhost, "events");
    try client.declareFanoutExchange(vhost, "events.dlx");

    const services = [_][]const u8{ "billing", "notifications", "analytics" };
    for (services) |service| {
        const queue_name = try std.fmt.allocPrint(allocator, "events.{s}", .{service});
        defer allocator.free(queue_name);
        const routing_key = try std.fmt.allocPrint(allocator, "{s}.*", .{service});
        defer allocator.free(routing_key);
        const dlq_name = try std.fmt.allocPrint(allocator, "events.{s}.dlq", .{service});
        defer allocator.free(dlq_name);

        var args: std.json.ObjectMap = .empty;
        defer args.deinit(allocator);
        try args.put(allocator, "x-dead-letter-exchange", .{ .string = "events.dlx" });
        try args.put(allocator, "x-queue-type", .{ .string = "quorum" });

        try client.declareQueue(vhost, queue_name, .{
            .durable = true,
            .arguments = .{ .object = args },
        });
        try client.bindQueue(vhost, "events", queue_name, .{ .routing_key = routing_key });

        try client.declareQuorumQueue(vhost, dlq_name);
        try client.bindQueue(vhost, "events.dlx", dlq_name, .{ .routing_key = "" });
    }
}
```

### Tear Down a Test Environment

Clean up after integration tests, ignoring missing resources:

```zig
fn teardownTestEnvironment(
    client: *api.Client,
    vhost: []const u8,
    users: []const []const u8,
) !void {
    if (client.listQueuesByVhost(vhost)) |queues| {
        defer queues.deinit();
        for (queues.value) |queue| {
            client.deleteQueue(vhost, queue.name, true) catch {};
        }
    } else |_| {}

    if (client.listExchangesByVhost(vhost)) |exchanges| {
        defer exchanges.deinit();
        for (exchanges.value) |exchange| {
            if (exchange.name.len == 0) continue;
            if (std.mem.startsWith(u8, exchange.name, "amq.")) continue;
            client.deleteExchange(vhost, exchange.name, true) catch {};
        }
    } else |_| {}

    if (client.listPoliciesByVhost(vhost)) |policies| {
        defer policies.deinit();
        for (policies.value) |policy| {
            if (policy.name) |policy_name| {
                client.deletePolicy(vhost, policy_name, true) catch {};
            }
        }
    } else |_| {}

    for (users) |user| client.deleteUser(user, true) catch {};
    client.deleteVhost(vhost, true) catch {};
}
```


## License

Dual licensed under [Apache License 2.0](LICENSE-APACHE) and [MIT](LICENSE-MIT).
