// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
pub const api = @import("rabbitmq_http_api_client");

pub const allocator = std.heap.page_allocator;
pub const testing = std.testing;

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

//
// Broker version probing for series-specific tests
//

pub const Version = struct {
    major: u32 = 0,
    minor: u32 = 0,
    patch: u32 = 0,
};

fn parseVersionPart(s: []const u8) u32 {
    const head = std.mem.sliceTo(s, '-');
    return std.fmt.parseInt(u32, head, 10) catch 0;
}

fn parseVersion(s: []const u8) Version {
    const base = std.mem.sliceTo(s, '+');
    var it = std.mem.splitScalar(u8, base, '.');
    const major = parseVersionPart(it.next() orelse "0");
    const minor = parseVersionPart(it.next() orelse "0");
    const patch = parseVersionPart(it.next() orelse "0");
    return .{ .major = major, .minor = minor, .patch = patch };
}

pub fn rabbitmqVersion() !Version {
    var client = try openClient();
    defer client.deinit();
    const ov = try client.getOverview();
    defer ov.deinit();
    const v = ov.value.rabbitmq_version orelse return error.RabbitmqVersionUnknown;
    return parseVersion(v);
}

pub fn rabbitmqVersionIsAtLeast(major: u32, minor: u32, patch: u32) !bool {
    const v = try rabbitmqVersion();
    if (v.major != major) return v.major > major;
    if (v.minor != minor) return v.minor > minor;
    return v.patch >= patch;
}

pub fn testingAgainstSeries(major: u32, minor: u32) !bool {
    const v = try rabbitmqVersion();
    return v.major == major and v.minor == minor;
}
