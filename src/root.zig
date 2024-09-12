const std = @import("std");
const testing = std.testing;

pub const Proc = struct {
    ctx: Context,
    del: u8,

    pub fn init(ctx: Context, del: u8) Proc {
        return Proc{
            .ctx = ctx,
            .del = del,
        };
    }

    pub fn process(self: *const @This(), dst: anytype, src: anytype) !void {
        var len: usize = 1;
        var olen: usize = 0;
        var depth: usize = 0;
        var buf: [4096]u8 = undefined;
        var out: [4096]u8 = undefined;

        while (len != 0) {
            len = try src.read(&buf);

            for (buf[0..len]) |ch| {
                if (self.ctx.forward == ch) {
                    depth += 1;
                } else if (self.ctx.backward == ch) {
                    depth -= 1;
                } else if (self.del == ch and depth != 0) {
                    continue;
                }

                out[olen] = ch;
                olen += 1;
            }

            try dst.writeAll(out[0..olen]);
            olen = 0;
        }
    }
};

pub const Context = struct {
    forward: u8,
    backward: u8,

    pub fn load(ch: u8) ?Context {
        for (MAPPING) |map| {
            if (ch == map.forward or ch == map.backward) {
                return map;
            }
        }

        return null;
    }
};

const MAPPING: [4]Context = .{
    .{ .forward = '{', .backward = '}' },
    .{ .forward = '[', .backward = ']' },
    .{ .forward = '<', .backward = '>' },
    .{ .forward = '(', .backward = ')' },
};

test "loading mapping" {
    try testing.expectEqual(Context.load('{'), Context{ .forward = '{', .backward = '}' });
    try testing.expectEqual(Context.load('}'), Context{ .forward = '{', .backward = '}' });

    try testing.expectEqual(Context.load('['), Context{ .forward = '[', .backward = ']' });
    try testing.expectEqual(Context.load(']'), Context{ .forward = '[', .backward = ']' });

    try testing.expectEqual(Context.load('('), Context{ .forward = '(', .backward = ')' });
    try testing.expectEqual(Context.load(')'), Context{ .forward = '(', .backward = ')' });

    try testing.expectEqual(Context.load('a'), null);
}

test "process hello fixture" {
    const sut = Proc.init(Context.load('{') orelse return error.NO_CONTEXT, '\n');

    const input = try std.fs.cwd().openFile("fixture/hello.in", .{ .mode = .read_only });
    const output = try std.fs.cwd().openFile("fixture/hello.out", .{ .mode = .read_only });

    var out = std.ArrayList(u8).init(testing.allocator);
    defer out.deinit();

    try sut.process(out.writer(), input.reader());

    var buf: [4096]u8 = undefined;
    var len: usize = 0;

    len = try output.reader().readAll(&buf);

    try testing.expectEqualStrings(buf[0..len], out.items);
}
