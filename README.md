# zig-dst

Born from a conversation on the Zig IRC channel, this library is a proof of concept of a helper utility for Dynamically Sized Types and arrays in Zig.

## Usage

This is a proof of concept so the API is bare right now, but the gist is there:

```zig
const Head = struct {
    head_val: u32,
};
const Middle = struct {
    middle_val: u32,
};
const Tail = struct {
    tail_val: u32,
};
const MyType = DynamicallySizedType(struct {
    head: Head,
    first: DynamicArray(u32),
    middle: Middle,
    second: DynamicArray(u8),
    tail: Tail,
});

var my_type = try MyType.init(testing.allocator, .{ 2, 4 });
defer my_type.deinit(testing.allocator);

const head = my_type.get(.head);
head.* = Head{ .head_val = 0xAA };

var first = my_type.get(.first);
first[0] = 0xC0FFEE;
first[1] = 0xBEEF;

const middle = my_type.get(.middle);
middle.* = Middle{ .middle_val = 0xBB };

var second = my_type.get(.second);
second[0] = 0xC0;
second[1] = 0xDE;
second[2] = 0xD0;
second[3] = 0x0D;

const tail = my_type.get(.tail);
tail.* = Tail{ .tail_val = 0xCC };
```
