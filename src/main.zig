const std = @import("std");

var stdout: @typeInfo(@TypeOf(std.fs.File.writer)).@"Fn".return_type.? = undefined;
var ciphertext: []u8 = undefined;
var key: []u8 = undefined;
var best_score: u32 = 0;

fn score_char(c: u8) u32 {
    return switch (c) {
        0x20, 0x41...0x5A, 0x61...0x7A => 3,
        0x30...0x39 => 2,
        0x21...0x2F, 0x3A...0x40, 0x5B...0x60, 0x7B...0x7E => 1,
        0x0...0x1F, 0x7F...0xFF => 0,
    };
}

fn try_key(plaintext: []u8) !void {
    var score: u32 = 0;
    for (ciphertext, plaintext, 0..) |c, *p, i| {
        p.* = c ^ key[i % key.len];
        score += score_char(p.*);
    }
    if (score >= best_score) {
        best_score = score;
        try stdout.print("{d}: ({s}) {s}\n---\n", .{score, key, plaintext});
    }
}

fn try_all_keys(depth: u8, plaintext: []u8) !void {
    if (depth >= key.len) return try try_key(plaintext);
    for (0..256) |c| {
        key[depth] = @intCast(c);
        try try_all_keys(depth + 1, plaintext);
    }
}

pub fn main() !void {
    stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cipher_hex = args[args.len - 1];
    ciphertext = try allocator.alloc(u8, cipher_hex.len / 2);
    defer allocator.free(ciphertext);
    ciphertext = try std.fmt.hexToBytes(ciphertext, cipher_hex);

    const key_full = try allocator.alloc(u8, ciphertext.len);
    defer allocator.free(key_full);
    const plaintext = try allocator.alloc(u8, ciphertext.len);
    defer allocator.free(plaintext);

    for (1..ciphertext.len) |key_length| {
        key = key_full[0..key_length];
        try try_all_keys(0, plaintext);
    }
}
