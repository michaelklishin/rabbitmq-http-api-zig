const h = @import("helpers.zig");
const std = @import("std");

test "connect via TLS 1.2 with custom CA cert" {
    var client = try h.api.Client.init(h.allocator, h.SharedIo.get(), .{
        .endpoint = "https://localhost:15671/api",
        .ca_cert_file = "/Users/antares/Development/Opensource/tls-gen.git/basic/result/ca_certificate.pem",
    });
    defer client.deinit();

    const overview = try client.getOverview();
    defer overview.deinit();
    try h.testing.expect(overview.value.rabbitmq_version != null);
}

test "TLS list vhosts" {
    var client = try h.api.Client.init(h.allocator, h.SharedIo.get(), .{
        .endpoint = "https://localhost:15671/api",
        .ca_cert_file = "/Users/antares/Development/Opensource/tls-gen.git/basic/result/ca_certificate.pem",
    });
    defer client.deinit();

    const vhosts = try client.listVhosts();
    defer vhosts.deinit();
    try h.testing.expect(vhosts.value.len > 0);
}
