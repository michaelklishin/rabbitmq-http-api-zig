const h = @import("helpers.zig");
const std = @import("std");

test "list vhosts" {
    var client = try h.openClient();
    defer client.deinit();

    const vhosts = try client.listVhosts();
    defer vhosts.deinit();

    try h.testing.expect(vhosts.value.len > 0);
    var found_default = false;
    for (vhosts.value) |v| {
        if (std.mem.eql(u8, v.name, "/")) found_default = true;
    }
    try h.testing.expect(found_default);
}

test "create, get, update, and delete vhost" {
    var client = try h.openClient();
    defer client.deinit();

    client.deleteVhost(h.test_vhost, true) catch {};

    try client.createVhost(h.test_vhost, .{
        .description = "Zig integration test vhost",
    });

    const vhost = try client.getVhost(h.test_vhost);
    defer vhost.deinit();
    try h.testing.expectEqualStrings(h.test_vhost, vhost.value.name);

    // Update (createVhost is an upsert)
    try client.createVhost(h.test_vhost, .{
        .description = "Updated description",
    });

    // Delete
    try client.deleteVhost(h.test_vhost, false);

    // Verify deleted
    const result = client.getVhost(h.test_vhost);
    try h.testing.expectError(error.NotFound, result);
}

test "create vhost with default queue type" {
    var client = try h.openClient();
    defer client.deinit();

    const vh = "zig.test.dqt.vhost";
    client.deleteVhost(vh, true) catch {};

    try client.createVhost(vh, .{
        .description = "Test vhost with DQT",
        .default_queue_type = "quorum",
    });

    const vhost = try client.getVhost(vh);
    defer vhost.deinit();
    if (vhost.value.default_queue_type) |dqt| {
        try h.testing.expectEqualStrings("quorum", dqt);
    }

    client.deleteVhost(vh, true) catch {};
}

test "delete vhost idempotently" {
    var client = try h.openClient();
    defer client.deinit();

    try client.deleteVhost("nonexistent-vhost-zig-test", true);
}

test "delete nonexistent vhost fails" {
    var client = try h.openClient();
    defer client.deinit();

    const result = client.deleteVhost("nonexistent-vhost-zig-test", false);
    try h.testing.expectError(error.NotFound, result);
}

test "virtual host deletion protection" {
    var client = try h.openClient();
    defer client.deinit();

    const vh = "zig.test.protected.vhost";
    client.deleteVhost(vh, true) catch {};
    try client.createVhost(vh, .{});

    try client.enableVhostDeletionProtection(vh);

    // Attempting to delete a protected vhost should fail
    if (client.deleteVhost(vh, false)) |_| {
        // Unexpected success — clean up
        return error.Unexpected;
    } else |_| {
        // Expected: deletion of protected vhost fails
    }

    try client.disableVhostDeletionProtection(vh);
    try client.deleteVhost(vh, false);
}

test "list vhosts paginated" {
    var client = try h.openClient();
    defer client.deinit();

    // Not all RabbitMQ series support virtual host listing with pagination
    const result = client.listVhostsPaged(.{ .page = 1, .page_size = 10 }) catch return;
    defer result.deinit();
    try h.testing.expect(result.value.items.len > 0);
}
