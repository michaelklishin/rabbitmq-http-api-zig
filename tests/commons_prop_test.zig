// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Michael Klishin

const std = @import("std");
const h = @import("helpers.zig");
const pt = @import("proptest");

const testing = std.testing;
const commons = h.api.commons;

fn pickVariant(comptime E: type, idx: u32) E {
    const variants = std.enums.values(E);
    return variants[idx % variants.len];
}

fn exchangeApiStringNonEmpty(idx: u32) !void {
    const s = pickVariant(commons.ExchangeType, idx).toApiString();
    if (s.len == 0) return error.EmptyApiString;
}

test "ExchangeType.toApiString is never empty" {
    var r = pt.Runner.initFromSeed(.{ .cases = 64, .log_failures = false }, 0x1234);
    try r.check(testing.allocator, pt.num.int(u32), exchangeApiStringNonEmpty);
}

fn queueApiStringNonEmpty(idx: u32) !void {
    const s = pickVariant(commons.QueueType, idx).toApiString();
    if (s.len == 0) return error.EmptyApiString;
}

test "QueueType.toApiString is never empty" {
    var r = pt.Runner.initFromSeed(.{ .cases = 64, .log_failures = false }, 0x2345);
    try r.check(testing.allocator, pt.num.int(u32), queueApiStringNonEmpty);
}

fn policyApiStringNonEmpty(idx: u32) !void {
    const s = pickVariant(commons.PolicyTarget, idx).toApiString();
    if (s.len == 0) return error.EmptyApiString;
}

test "PolicyTarget.toApiString is never empty" {
    var r = pt.Runner.initFromSeed(.{ .cases = 64, .log_failures = false }, 0x3456);
    try r.check(testing.allocator, pt.num.int(u32), policyApiStringNonEmpty);
}

fn protocolApiStringNonEmpty(idx: u32) !void {
    const s = pickVariant(commons.SupportedProtocol, idx).toApiString();
    if (s.len == 0) return error.EmptyApiString;
}

test "SupportedProtocol.toApiString is never empty" {
    var r = pt.Runner.initFromSeed(.{ .cases = 64, .log_failures = false }, 0x4567);
    try r.check(testing.allocator, pt.num.int(u32), protocolApiStringNonEmpty);
}

fn policyTargetApplyToReflexive(idx: u32) !void {
    const t = pickVariant(commons.PolicyTarget, idx);
    if (!t.doesApplyTo(t)) return error.NonReflexive;
}

test "PolicyTarget.doesApplyTo is reflexive" {
    var r = pt.Runner.initFromSeed(.{ .cases = 32, .log_failures = false }, 0x5678);
    try r.check(testing.allocator, pt.num.int(u32), policyTargetApplyToReflexive);
}

test "PolicyTarget.all never applies to exchanges" {
    try testing.expect(!commons.PolicyTarget.all.doesApplyTo(.exchanges));
}
