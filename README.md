# zig-restruct

Born from a conversation on the Zig IRC channel, this library is a proof of concept of a helper utility for runtime sized types and arrays in Zig.

## Usage

This is a proof of concept so the API is bare right now, but the gist is there:

```zig
const restruct = @import("restruct");
const ResizableArray = restruct.ResizableArray;
const ResizableStruct = restruct.ResizableStruct;

// Declare some known-sized structs.
const Head = struct {
    head_val: u32,
};

const Middle = struct {
    middle_val: u32,
};

const Tail = struct {
    tail_val: u32,
};

// Combine them in a ResizableStruct with some ResizableArray(T) fields.
const MyType = ResizableStruct(struct {
    head: Head,
    first: ResizableArray(u32),
    middle: Middle,
    second: ResizableArray(u8),
    tail: Tail,
});

// Allocate some memory by passing a struct of array lengths for all ResizableArray fields.
var my_type = try MyType.init(testing.allocator, .{
    .first = 2,
    .second = 4,
});
defer my_type.deinit(testing.allocator);

// Get pointers to the fields in the struct.
const head = my_type.get(.head);
head.* = Head{ .head_val = 0xAA };

const middle = my_type.get(.middle);
middle.* = Middle{ .middle_val = 0xBB };

const tail = my_type.get(.tail);
tail.* = Tail{ .tail_val = 0xCC };

// Get slices of the resizable arrays.
var first = my_type.get(.first);
first[0] = 0xC0FFEE;
first[1] = 0xBEEF;

var second = my_type.get(.second);
second[0] = 0xC0;
second[1] = 0xDE;
second[2] = 0xD0;
second[3] = 0x0D;
```
