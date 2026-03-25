const std = @import("std");
pub const api = @import("rabbitmq_http_api_client");

pub const allocator = std.heap.page_allocator;
pub const testing = std.testing;

pub const test_vhost = "zig.http.api.client.test";
pub const test_user = "zig-test-user";

pub const SharedIo = struct {
    var instance: ?*std.Io.Threaded = null;

    pub fn get() std.Io {
        if (instance == null) {
            instance = allocator.create(std.Io.Threaded) catch @panic("OOM");
            instance.?.* = std.Io.Threaded.init(allocator, .{});
        }
        return instance.?.io();
    }
};

pub fn openClient() !api.Client {
    return api.Client.init(allocator, SharedIo.get(), .{});
}
