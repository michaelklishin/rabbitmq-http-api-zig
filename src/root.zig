/// RabbitMQ HTTP API Client for Zig.
///
/// An HTTP client for the RabbitMQ management API, using Zig's
/// `std.Io` interface for pluggable I/O (threaded, async, simulated).
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
