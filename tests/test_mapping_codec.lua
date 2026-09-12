local t = require "t"
local C = require "MappingCodec"

t.eq(C.encode({}), "v1|", "encode empty")
t.eq(C.decode(C.encode({ [123] = 456, [7] = 8 })), { [123] = 456, [7] = 8 }, "round trip")
t.eq(C.encode({ [123] = 456, [7] = 8 }), "v1|7:8,123:456", "deterministic order")
t.eq(C.decode(nil), {}, "decode nil")
t.eq(C.decode(""), {}, "decode empty string")
t.eq(C.decode("garbage"), {}, "decode garbage")
t.eq(C.decode("v9|1:2"), {}, "unknown version")
t.eq(C.decode("v1|1:2,bad,3:4"), { [1] = 2, [3] = 4 }, "skips malformed pair")
t.eq(C.decode(42), {}, "decode non-string")

t.report("test_mapping_codec")
