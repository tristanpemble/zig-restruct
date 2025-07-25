/// This type is zero sized and has no methods. It exists as an API for `ResizableStruct`,
/// indicating which fields are runtime sized arrays of elements.
pub fn ResizableArray(comptime T: type) type {
    return struct {
        pub const Element = T;
    };
}

fn isResizableArray(comptime T: type) bool {
    return @hasDecl(T, "Element") and T == ResizableArray(T.Element);
}

/// A heap allocated type that can be sized at runtime to contain any number of `ResizableArray`s.
///
/// Internally, it is represented as a pointer and a set of lengths for each `ResizableArray` field.
pub fn ResizableStruct(comptime Layout: type) type {
    return struct {
        const Self = @This();

        const Alignment = blk: {
            var alignment = 0;
            for (@typeInfo(Layout).@"struct".fields) |field| {
                const tag = @field(FieldEnum(Layout), field.name);
                alignment = @max(alignment, alignOf(tag));
            }
            break :blk alignment;
        };

        /// A comptime generated struct type containing `usize` length fields for each `ResizableArray` field of `Layout`.
        pub const Lengths = blk: {
            var fields: [@typeInfo(Layout).@"struct".fields.len]StructField = undefined;
            var i: usize = 0;
            for (@typeInfo(Layout).@"struct".fields) |field| {
                if (isResizableArray(field.type)) {
                    fields[i] = .{
                        .name = field.name,
                        .type = usize,
                        .default_value_ptr = @ptrCast(&@as(usize, 0)),
                        .is_comptime = false,
                        .alignment = @alignOf(usize),
                    };
                    i += 1;
                }
            }
            break :blk @Type(.{
                .@"struct" = .{
                    .layout = .auto,
                    .fields = fields[0..i],
                    .decls = &.{},
                    .is_tuple = false,
                },
            });
        };

        /// The pointer to the struct's data.
        ptr: [*]align(Alignment) u8,

        /// The length of each `ResizableArray` field.
        lens: Lengths,

        /// Initializes a new instance of the struct with the given lengths for its `ResizableArray` fields.
        pub fn init(allocator: Allocator, lens: Lengths) Oom!Self {
            const size = calcSize(lens);
            const bytes = try allocator.alignedAlloc(u8, Alignment, size);

            return Self{ .ptr = bytes.ptr, .lens = lens };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.ptr[0..calcSize(self.lens)]);
            self.* = undefined;
        }

        pub fn resize(self: *Self, allocator: Allocator, new_lens: Lengths) Oom!void {
            _ = self; // autofix
            _ = allocator; // autofix
            _ = new_lens; // autofix
        }

        pub fn remap(self: *Self, allocator: Allocator, new_lens: Lengths) Oom!void {
            _ = self; // autofix
            _ = allocator; // autofix
            _ = new_lens; // autofix
        }

        /// Returns a pointer to the given field. If the field is a `ResizableArray`, returns a slice of elements.
        pub fn get(self: Self, comptime field: FieldEnum(Layout)) blk: {
            const Field = @FieldType(Layout, @tagName(field));
            break :blk if (isResizableArray(Field)) []Field.Element else *Field;
        } {
            const start = self.offsetOf(field);
            const end = start + self.sizeOf(field);
            const bytes = self.ptr[start..end];

            return @ptrCast(@alignCast(bytes));
        }

        /// Returns a const pointer to the given field. If the field is a `ResizableArray`, returns a const slice of elements.
        pub fn getConst(self: *const Self, comptime field: FieldEnum(Layout)) blk: {
            const Field = @FieldType(Layout, @tagName(field));
            break :blk if (isResizableArray(Field)) []const Field.Element else *const Field;
        } {
            const start = self.offsetOf(field);
            const end = start + self.sizeOf(field);
            const bytes = self.ptr[start..end];

            return @ptrCast(@alignCast(bytes));
        }

        /// Returns the byte offset of the given field.
        pub fn offsetOf(self: *const Self, comptime field: FieldEnum(Layout)) usize {
            var offset: usize = 0;
            inline for (@typeInfo(Layout).@"struct".fields) |f| {
                const tag = @field(FieldEnum(Layout), f.name);
                if (tag == field) {
                    return offset;
                } else {
                    offset += self.sizeOf(tag);
                }
            }
            unreachable;
        }

        /// Returns the byte size of the given field, calculating the size of `ResizableArray` fields using their length.
        pub fn sizeOf(self: *const Self, comptime field: FieldEnum(Layout)) usize {
            const Field = @FieldType(Layout, @tagName(field));
            if (comptime isResizableArray(Field)) {
                return @sizeOf(Field.Element) * @field(self.lens, @tagName(field));
            } else {
                return @sizeOf(Field);
            }
        }

        /// Returns the byte alignment of the given field.
        fn alignOf(comptime field: FieldEnum(Layout)) usize {
            const Field = @FieldType(Layout, @tagName(field));
            if (comptime isResizableArray(Field)) {
                return @alignOf(Field.Element);
            } else {
                return @alignOf(Field);
            }
        }

        /// Calculate the byte size of this struct given the lengths of its `ResizableArray` fields.
        fn calcSize(lens: Lengths) usize {
            var size: usize = 0;
            inline for (@typeInfo(Layout).@"struct".fields) |f| {
                if (comptime isResizableArray(f.type)) {
                    size += @sizeOf(f.type.Element) * @field(lens, f.name);
                } else {
                    size += @sizeOf(f.type);
                }
            }
            return size;
        }
    };
}

test "manually created" {
    const Head = struct {
        head_val: u32,
    };
    const Middle = struct {
        middle_val: u32,
    };
    const Tail = struct {
        tail_val: u32,
    };
    const MyType = ResizableStruct(struct {
        head: Head,
        first: ResizableArray(u32),
        middle: Middle,
        second: ResizableArray(u8),
        tail: Tail,
    });

    const my_type = MyType{
        .ptr = @ptrCast(@constCast(&[_]u32{
            0xAA,
            0xC0FFEE,
            0xBEEF,
            0xBB,
            std.mem.bigToNative(u32, 0xC0DED00D),
            0xCC,
        })),
        .lens = .{
            .first = 2,
            .second = 4,
        },
    };

    try testing.expectEqualDeep(&Head{ .head_val = 0xAA }, my_type.getConst(.head));
    try testing.expectEqualSlices(u32, &.{ 0xC0FFEE, 0xBEEF }, my_type.getConst(.first));
    try testing.expectEqualDeep(&Middle{ .middle_val = 0xBB }, my_type.getConst(.middle));
    try testing.expectEqualSlices(u8, &.{ 0xC0, 0xDE, 0xD0, 0x0D }, my_type.getConst(.second));
    try testing.expectEqualDeep(&Tail{ .tail_val = 0xCC }, my_type.getConst(.tail));
}

test "allocated" {
    const Head = struct {
        head_val: u32,
    };
    const Middle = struct {
        middle_val: u32,
    };
    const Tail = struct {
        tail_val: u32,
    };
    const MyType = ResizableStruct(struct {
        head: Head,
        first: ResizableArray(u32),
        middle: Middle,
        second: ResizableArray(u8),
        tail: Tail,
    });

    var my_type = try MyType.init(testing.allocator, .{
        .first = 2,
        .second = 4,
    });
    defer my_type.deinit(testing.allocator);

    const head = my_type.get(.head);
    head.* = Head{ .head_val = 0xAA };
    const first = my_type.get(.first);
    first[0] = 0xC0FFEE;
    first[1] = 0xBEEF;
    const middle = my_type.get(.middle);
    middle.* = Middle{ .middle_val = 0xBB };
    const second = my_type.get(.second);
    second[0] = 0xC0;
    second[1] = 0xDE;
    second[2] = 0xD0;
    second[3] = 0x0D;
    const tail = my_type.get(.tail);
    tail.* = Tail{ .tail_val = 0xCC };

    try testing.expectEqualDeep(&Head{ .head_val = 0xAA }, my_type.getConst(.head));
    try testing.expectEqualSlices(u32, &.{ 0xC0FFEE, 0xBEEF }, my_type.getConst(.first));
    try testing.expectEqualDeep(&Middle{ .middle_val = 0xBB }, my_type.getConst(.middle));
    try testing.expectEqualSlices(u8, &.{ 0xC0, 0xDE, 0xD0, 0x0D }, my_type.getConst(.second));
    try testing.expectEqualDeep(&Tail{ .tail_val = 0xCC }, my_type.getConst(.tail));
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const FieldEnum = std.meta.FieldEnum;
const Oom = std.mem.Allocator.Error;
const StructField = std.builtin.Type.StructField;
const testing = std.testing;
