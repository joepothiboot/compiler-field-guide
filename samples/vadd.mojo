from std.sys import simd_width_of


def vadd(a: List[Float32], b: List[Float32], mut c: List[Float32]):
    comptime width = simd_width_of[DType.float32]()
    var n = len(a)
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()
    var i = 0
    while i + width <= n:  # SIMD body: `width` lanes per step
        pc.unsafe_store(i, pa.unsafe_load[width=width](i) + pb.unsafe_load[width=width](i))
        i += width
    while i < n:  # scalar tail for the leftovers
        pc[unsafe_offset=i] = pa[unsafe_offset=i] + pb[unsafe_offset=i]
        i += 1


def main():
    var a = List[Float32](length=10, fill=1.5)
    var b = List[Float32](length=10, fill=2.0)
    var c = List[Float32](length=10, fill=0)
    vadd(a, b, c)
    print(c[0], c[9], simd_width_of[DType.float32]())
