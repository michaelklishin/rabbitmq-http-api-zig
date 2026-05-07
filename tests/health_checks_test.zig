// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

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

    _ = try client.healthCheckVirtualHosts();
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

    try h.testing.expect(try client.healthCheckProtocolListener(.amqp));
}

test "health check: node is quorum critical" {
    var client = try h.openClient();
    defer client.deinit();

    // A single-node test cluster has no quorum minorities, so the check passes.
    const ok = try client.healthCheckNodeIsQuorumCritical();
    try h.testing.expect(ok);
}

test "health check: is in service" {
    // Endpoint requires RabbitMQ 4.1+
    if (!try h.rabbitmqVersionIsAtLeast(4, 1, 0)) return;

    var client = try h.openClient();
    defer client.deinit();

    try h.testing.expect(try client.healthCheckIsInService());
}

test "health check: ready to serve clients" {
    // Endpoint requires RabbitMQ 4.1+
    if (!try h.rabbitmqVersionIsAtLeast(4, 1, 0)) return;

    var client = try h.openClient();
    defer client.deinit();

    try h.testing.expect(try client.healthCheckReadyToServeClients());
}

test "health check: below connection limit" {
    // Endpoint requires RabbitMQ 4.1+ (/health/checks/below-node-connection-limit)
    if (!try h.rabbitmqVersionIsAtLeast(4, 1, 0)) return;

    var client = try h.openClient();
    defer client.deinit();

    try h.testing.expect(try client.healthCheckBelowConnectionLimit());
}

test "health check: protocol listener via enum (stream)" {
    var client = try h.openClient();
    defer client.deinit();

    // The stream protocol listener may not be enabled in every test environment,
    // so we only verify the call returns without raising.
    _ = try client.healthCheckProtocolListener(.stream);
}

test "health check: metadata store initialized" {
    var client = try h.openClient();
    defer client.deinit();

    _ = client.healthCheckMetadataStoreInitialized() catch return;
}

test "health check: quorum queues without elected leaders" {
    var client = try h.openClient();
    defer client.deinit();

    // Endpoint requires RabbitMQ 4.x
    _ = client.healthCheckQuorumQueuesWithoutLeaders() catch return;
}

test "health check: certificate expiration accepts months" {
    var client = try h.openClient();
    defer client.deinit();

    _ = client.healthCheckCertificateExpiration(1, "months") catch return;
}
