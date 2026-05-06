// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const h = @import("helpers.zig");
const std = @import("std");
const testing = std.testing;

// These tests follow the directory layout produced by tls-gen
// (https://github.com/rabbitmq/tls-gen). Point `TLS_CERTS_DIR` at a
// `basic/result/` (or `advanced/result/`) directory and the suite picks
// `ca_certificate.pem` out of it. Each test skips when the env var is unset.

fn caPath(buf: []u8) ?[]const u8 {
    const certs_dir = testing.environ.getPosix("TLS_CERTS_DIR") orelse return null;
    return std.fmt.bufPrint(buf, "{s}/ca_certificate.pem", .{certs_dir}) catch null;
}

test "connect via TLS with a custom CA bundle" {
    var ca_buf: [1024]u8 = undefined;
    const ca_path = caPath(&ca_buf) orelse return error.SkipZigTest;

    var client = try h.api.Client.init(h.allocator, h.SharedIo.get(), .{
        .endpoint = "https://localhost:15671/api",
        .ca_cert_file = ca_path,
    });
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    try testing.expect(overview.value.rabbitmq_version != null);
}

test "TLS list vhosts" {
    var ca_buf: [1024]u8 = undefined;
    const ca_path = caPath(&ca_buf) orelse return error.SkipZigTest;

    var client = try h.api.Client.init(h.allocator, h.SharedIo.get(), .{
        .endpoint = "https://localhost:15671/api",
        .ca_cert_file = ca_path,
    });
    defer client.deinit();

    const vhosts = try client.listVhosts();
    defer vhosts.deinit();
    try testing.expect(vhosts.value.len > 0);
}
