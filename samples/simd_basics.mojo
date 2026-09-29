from std.sys import simd_width_of


def main():
    comptime f32_width = simd_width_of[DType.float32]()
    comptime f16_width = simd_width_of[DType.float16]()
    comptime i8_width = simd_width_of[DType.int8]()
    print("native lanes  f32:", f32_width, " f16:", f16_width, " i8:", i8_width)

    var a = SIMD[DType.float32, 4](1.0, -2.0, 3.0, -4.0)
    var b = SIMD[DType.float32, 4](10.0)  # splat: every lane = 10
    print("a      =", a)
    print("a + b  =", a + b)
    print("a * a  =", a * a)
    print("sum(a) =", a.reduce_add())
    print("max(a) =", a.reduce_max())
    var zeros = SIMD[DType.float32, 4](0)
    print("relu(a)=", a.lt(zeros).select(zeros, a))
    print("a[2]   =", a[2])
