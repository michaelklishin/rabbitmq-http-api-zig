// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

/// RabbitMQ HTTP API Client for Zig.
///
/// HTTP client for the RabbitMQ management API, built on Zig's std.Io for
/// pluggable I/O (threaded, async, simulated).
pub const Client = @import("client.zig").Client;
pub const ClientOptions = @import("client.zig").ClientOptions;
pub const ClientError = @import("client.zig").ClientError;
pub const percentEncode = @import("client.zig").percentEncode;
pub const responses = @import("responses.zig");
pub const requests = @import("requests.zig");
pub const commons = @import("commons.zig");
pub const builders = @import("builders.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
