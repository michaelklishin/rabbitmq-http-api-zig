const h = @import("helpers.zig");
const std = @import("std");

test "health check: cluster alarms" {
    var client = try h.openClient();
    defer client.deinit();

    const healthy = try client.healthCheckClusterAlarms();
    try h.testing.expect(healthy);
}

test "health check: local alarms" {
    var client = try h.openClient();
    defer client.deinit();

    const healthy = try client.healthCheckLocalAlarms();
    try h.testing.expect(healthy);
}

test "health check: virtual hosts" {
    var client = try h.openClient();
    defer client.deinit();

    const healthy = try client.healthCheckVirtualHosts();
    try h.testing.expect(healthy);
}

test "health check: port listener succeeds" {
    var client = try h.openClient();
    defer client.deinit();

    const listening = try client.healthCheckPortListener(5672);
    try h.testing.expect(listening);
}

test "health check: port listener fails" {
    var client = try h.openClient();
    defer client.deinit();

    const listening = try client.healthCheckPortListener(15679);
    try h.testing.expect(!listening);
}

test "health check: protocol listener succeeds" {
    var client = try h.openClient();
    defer client.deinit();

    try h.testing.expect(try client.healthCheckProtocolListener("amqp"));
}

test "health check: node is quorum critical" {
    var client = try h.openClient();
    defer client.deinit();

    // On a single node cluster this should return true (not critical)
    const ok = try client.healthCheckNodeIsQuorumCritical();
    try h.testing.expect(ok);
}

test "health check: is in service" {
    var client = try h.openClient();
    defer client.deinit();

    try h.testing.expect(try client.healthCheckIsInService());
}

test "health check: ready to serve clients" {
    var client = try h.openClient();
    defer client.deinit();

    try h.testing.expect(try client.healthCheckReadyToServeClients());
}

test "health check: below connection limit" {
    var client = try h.openClient();
    defer client.deinit();

    try h.testing.expect(try client.healthCheckBelowConnectionLimit());
}
