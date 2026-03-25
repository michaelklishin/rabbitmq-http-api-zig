const h = @import("helpers.zig");
const std = @import("std");

test "list federation links" {
    var client = try h.openClient();
    defer client.deinit();

    const links = try client.listFederationLinks();
    defer links.deinit();
}

test "list federation links by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const links = try client.listFederationLinksByVhost("/");
    defer links.deinit();
}

test "list shovels" {
    var client = try h.openClient();
    defer client.deinit();

    const shovels = try client.listShovels();
    defer shovels.deinit();
}

test "list shovels by vhost" {
    var client = try h.openClient();
    defer client.deinit();

    const shovels = try client.listShovelsByVhost("/");
    defer shovels.deinit();
}
