const h = @import("helpers.zig");
const std = @import("std");

test "export definitions" {
    var client = try h.openClient();
    defer client.deinit();

    const defs = try client.exportDefinitions();
    defer defs.deinit();
    try h.testing.expect(defs.value.rabbitmq_version != null);
}

test "export definitions as string" {
    var client = try h.openClient();
    defer client.deinit();

    const json = try client.exportDefinitionsAsString();
    defer h.allocator.free(json);
    try h.testing.expect(json.len > 0);
    // Should be valid JSON starting with {
    try h.testing.expect(json[0] == '{');
}

test "export vhost definitions" {
    var client = try h.openClient();
    defer client.deinit();

    const defs = try client.exportVhostDefinitions("/");
    defer defs.deinit();
}

test "import definitions" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.imported.queue";
    client.deleteQueue("/", queue_name, true) catch {};

    // Import a minimal definition with a queue
    const defs =
        \\{"queues":[{"name":"zig.test.imported.queue","vhost":"/","durable":true,"auto_delete":false,"arguments":{}}]}
    ;
    try client.importDefinitions(defs);

    const info = try client.getQueueInfo("/", queue_name);
    defer info.deinit();
    try h.testing.expectEqualStrings(queue_name, info.value.name);

    client.deleteQueue("/", queue_name, true) catch {};
}

test "import definitions via importDefinitions" {
    var client = try h.openClient();
    defer client.deinit();

    const queue_name = "zig.test.imported.via.api";
    client.deleteQueue("/", queue_name, true) catch {};

    const defs =
        \\{"queues":[{"name":"zig.test.imported.via.api","vhost":"/","durable":true,"auto_delete":false,"arguments":{}}]}
    ;
    try client.importDefinitions(defs);

    const info = try client.getQueueInfo("/", queue_name);
    defer info.deinit();
    try h.testing.expectEqualStrings(queue_name, info.value.name);

    client.deleteQueue("/", queue_name, true) catch {};
}
