// -*- coding:utf-8 -*-

//
// Pentomino Puzzle Solver with Zig
//

const PIECE_DEF =
    \\+-------+-------+-------+-------+-------+-------+
    \\|       |   I   |  L    |  N    |       |       |
    \\|   F F |   I   |  L    |  N    |  P P  | T T T |
    \\| F F   |   I   |  L    |  N N  |  P P  |   T   |
    \\|   F   |   I   |  L L  |    N  |  P    |   T   |
    \\|       |   I   |       |       |       |       |
    \\+-------+-------+-------+-------+-------+-------+
    \\|       | V     | W     |   X   |    Y  | Z Z   |
    \\| U   U | V     | W W   | X X X |  Y Y  |   Z   |
    \\| U U U | V V V |   W W |   X   |    Y  |   Z Z |
    \\|       |       |       |       |    Y  |       |
    \\+-------+-------+-------+-------+-------+-------+
    \\!
;

const std = @import("std");
const print = std.debug.print;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const builtin = @import("builtin");

/////////////////////////////////////////////////////////////

var debug_flg: bool = false;

fn piece_def(id: u8) *Fig {
    const static = struct {
        var fig: Fig = undefined;
    };

    var x: usize = 0;
    var y: usize = 0;
    var n: usize = 0;

    for (PIECE_DEF) |c| {
        if (c == id and n < 5) {
            static.fig.pts[n] = Point{ .x = @intCast(x / 2), .y = @intCast(y) };
            n += 1;
        }
        if (c == '\n') {
            x = 0;
            y += 1;
        } else {
            x += 1;
        }
    }

    return &static.fig;
}

const Point = struct {
    x: i32,
    y: i32,

    fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    fn comp_pt(_: void, a: Point, b: Point) bool {
        if (a.y == b.y) {
            return a.x < b.x;
        }
        return a.y < b.y;
    }
};

const Fig = struct {
    const Self = @This();

    pts: [5]Point,

    fn eql(self: *Self, other: *Self) bool {
        for (self.pts, 0..) |p, i| {
            if (!p.eql(other.pts[i])) return false;
        }
        return true;
    }

    fn to_s(self: *const Self) []u8 {
        const static = struct {
            var buf: [128]u8 = undefined;
        };

        var stream = std.io.fixedBufferStream(&static.buf);
        const writer = stream.writer();
        writer.print("[ ", .{}) catch {};
        for (self.pts, 0..) |xy, i| {
            writer.print("({:3},{:3})", .{ xy.x, xy.y }) catch {};
            if (i < self.pts.len - 1) {
                writer.print(", ", .{}) catch {};
            }
        }
        writer.print(" ]", .{}) catch {};
        return static.buf[0..stream.pos];
    }
};

const Piece = struct {
    const Self = @This();

    id: u8,
    figs: []Fig = undefined,
    next: ?*Piece,

    fn new(id: u8, fig_def: *const Fig, next: ?*Piece) !*Self {
        var figs = try allocator.alloc(Fig, 8);
        var figs_n: usize = 0;
        for (0..figs.len) |r_f| { // rotate & flip
            var fig: Fig = undefined;

            for (fig_def.pts, 0..) |_xy, i| {
                var xy = _xy;
                for (0..(r_f % 4)) |_| { // rotate
                    xy = Point{ .x = -xy.y, .y = xy.x };
                }
                if (r_f >= 4) xy.x = -xy.x; // flip
                fig.pts[i] = xy;
            }
            std.mem.sort(Point, &fig.pts, {}, Point.comp_pt); // sort

            const first: Point = fig.pts[0]; // normalize
            for (&fig.pts) |*pp| {
                pp.x -= first.x;
                pp.y -= first.y;
            }

            var uniq = false;
            for (0..figs_n) |i| { // uniq
                if (figs[i].eql(&fig)) {
                    uniq = true;
                    break;
                }
            }
            if (!uniq) {
                figs[figs_n] = fig; // struct copy
                figs_n += 1;
            }
        }

        if (debug_flg) {
            print("{c}: ({d})\n", .{ id, figs_n });
            for (0..figs_n) |i| {
                print("\t{s}\n", .{figs[i].to_s()});
            }
        }
        const pc = try allocator.create(Piece);
        pc.* = Self{
            .id = id,
            .figs = figs[0..figs_n],
            .next = next,
        };

        return pc;
    }
};

///////////////////////////////////////////////////////////

const Board = struct {
    const Self = @This();
    const SPACE = ' ';
    width: usize,
    height: usize,
    cells: [][]u8,

    fn new(width: usize, height: usize) !*Self {
        var cells = try allocator.alloc([]u8, height);

        for (0..height) |h| {
            cells[h] = try allocator.alloc(u8, width);
            for (0..width) |w| {
                cells[h][w] = SPACE;
            }
        }

        const bd = try allocator.create(Board);
        bd.* = Board{
            .width = width,
            .height = height,
            .cells = cells,
        };

        if (width * height == 64) { // 8x8 or 4x16
            const hole = Fig{ .pts = .{
                .{ .x = 0, .y = 0 },
                .{ .x = 0, .y = 1 },
                .{ .x = 1, .y = 0 },
                .{ .x = 1, .y = 1 },
                .{ .x = 1, .y = 1 },
            } };
            const o = Point{
                .x = @intCast(width / 2 - 1),
                .y = @intCast(height / 2 - 1),
            };
            bd.place(o, &hole, '@');
        }

        return bd;
    }

    fn at(self: *const Self, x: i32, y: i32) u8 {
        if (x >= 0 and x < self.width and y >= 0 and y < self.height) {
            return self.cells[@intCast(y)][@intCast(x)];
        } else {
            return '?';
        }
    }

    fn check(self: *const Self, xy: Point, fig: *const Fig) bool {
        for (fig.pts) |pt| {
            if (self.at(xy.x + pt.x, xy.y + pt.y) != SPACE) {
                return false;
            }
        }
        return true;
    }

    fn place(self: *const Self, xy: Point, fig: *const Fig, id: u8) void {
        for (fig.pts) |pt| {
            self.cells[@intCast(xy.y + pt.y)][@intCast(xy.x + pt.x)] = id;
        }
    }

    fn find_space(self: *const Self, xy: Point) Point {
        var x = xy.x;
        var y = xy.y;
        while (self.cells[@intCast(y)][@intCast(x)] != SPACE) {
            x += 1;
            if (x == self.width) {
                x = 0;
                y += 1;
            }
        }
        return Point{ .x = x, .y = y };
    }

    //         2
    // (-1,-1) | (0,-1)
    //   ---4--+--1----
    // (-1, 0) | (0, 0)
    //         8
    const ELEMS: [2][16][:0]const u8 = .{
        .{ "    ", "", "", "+---", "", "----", "+   ", "+---", "", "+---", "|   ", "+---", "+   ", "+---", "+   ", "+---" },
        .{ "    ", "", "", "    ", "", "    ", "    ", "    ", "", "|   ", "|   ", "|   ", "|   ", "|   ", "|   ", "|   " },
    };

    fn render(self: *const Self) []u8 {
        const static = struct {
            var buf: [1024]u8 = undefined; // may be enough size
        };
        var stream = std.io.fixedBufferStream(&static.buf);
        const writer = stream.writer();

        for (0..self.height + 1) |uy| {
            for (0..2) |d| {
                for (0..self.width + 1) |ux| {
                    const x: i32 = @intCast(ux);
                    const y: i32 = @intCast(uy);
                    var code: usize = 0;
                    if (self.at(x + 0, y + 0) != self.at(x + 0, y - 1)) code += 1;
                    if (self.at(x + 0, y - 1) != self.at(x - 1, y - 1)) code += 2;
                    if (self.at(x - 1, y - 1) != self.at(x - 1, y + 0)) code += 4;
                    if (self.at(x - 1, y + 0) != self.at(x + 0, y + 0)) code += 8;
                    writer.print("{s}", .{ELEMS[d][code]}) catch {};
                }
                if (uy < self.height or d < 1) {
                    writer.print("\n", .{}) catch {};
                }
            }
        }

        return static.buf[0..stream.pos];
    }
};

const Solver = struct {
    const Self = @This();

    unused: *Piece = undefined,
    board: *Board = undefined,
    head: Piece = undefined,
    solutions: usize = undefined,

    fn new(width: usize, height: usize) !*Self {
        var pc: ?*Piece = null;
        const ids: []const u8 = "FILNPTUVWXYZ";
        for (ids, 0..) |_, i| {
            const id = ids[ids.len - i - 1];
            pc = try Piece.new(id, piece_def(id), pc);
        }

        // limit the symmetry of 'F'
        const pc_F = pc.?;
        if (width == height) {
            pc_F.figs = pc_F.figs[0..1];
        } else {
            pc_F.figs = pc_F.figs[0..2];
        }

        const solver = try allocator.create(Solver);
        solver.* = Solver{
            .board = try Board.new(width, height),
            .head = Piece{ .id = '!', .next = pc_F }, // dummy piece
            .solutions = 0,
        };
        solver.unused = &solver.head;

        return solver;
    }

    fn solve(self: *Self, xy_: Point) void {
        if (self.unused.next != null) {
            const xy: Point = self.board.find_space(xy_);
            var prev: *Piece = self.unused;
            var pc: ?*Piece = null;
            while (true) {
                pc = prev.next;
                if (pc == null) break;

                prev.next = pc.?.next;
                for (pc.?.figs) |fig| {
                    if (self.board.check(xy, &fig)) {
                        self.board.place(xy, &fig, pc.?.id);
                        self.solve(xy); // call recursively
                        self.board.place(xy, &fig, Board.SPACE);
                    }
                }
                prev.next = pc;
                prev = pc.?;
            }
        } else {
            self.solutions += 1;
            if (self.solutions > 1) {
                print("\x1b[{d}A", .{2 * self.board.height + 2}); // curs up
            }
            print("{s}{d}\n", .{ self.board.render(), self.solutions });
        }
    }
};

pub fn main() !void {
    var width: usize = 6;
    var height: usize = 10;

    var args: [][:0]u8 = undefined;
    if (builtin.os.tag == .windows) {
        args = try std.process.argsAlloc(allocator);
    } else {
        const lnx_args = std.os.argv;
        args = try allocator.alloc([:0]u8, lnx_args.len);
        for (args, lnx_args) |*dst, src| {
            dst.* = std.mem.sliceTo(src, 0); // null 終端までのスライス
        }
    }

    for (args[1..], 1..) |arg, i| { // skip args[0]
        print("arg[{d}]: {s}\n", .{ i, arg });

        if (std.mem.eql(u8, arg, "--debug")) {
            debug_flg = true;
        }

        const x_pos = std.mem.indexOf(u8, arg, "x");
        if (x_pos != null) {
            const width_str = arg[0..x_pos.?];
            const height_str = arg[x_pos.? + 1 ..];
            const w = try std.fmt.parseInt(u32, width_str, 10);
            const h = try std.fmt.parseInt(u32, height_str, 10);
            if (w >= 3 and h >= 3 and (w * h == 60 or w * h == 64)) {
                width = w;
                height = h;
            }
            print("{d}x{d}\n", .{ width, height });
        }
    }

    var solver = try Solver.new(width, height);

    solver.solve(Point{ .x = 0, .y = 0 });
}
