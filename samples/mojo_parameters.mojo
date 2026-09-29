# Parameters [..] are compile-time inputs; arguments (..) are runtime inputs.
from std.sys import simd_width_of


def repeat[count: Int](msg: String):  # count is known when compiling
    comptime for i in range(count):  # unrolled: `count` copies of the body
        print("  ", i, msg)


@fieldwise_init
struct Vec[dtype: DType, size: Int](Copyable):  # a parametric struct
    var data: SIMD[Self.dtype, Self.size]

    def dot(self, other: Self) -> Scalar[Self.dtype]:
        return (self.data * other.data).reduce_add()


def sum_simd[dtype: DType, width: Int = simd_width_of[dtype]()](
    x: SIMD[dtype, width]
) -> Scalar[dtype]:
    return x.reduce_add()  # `width` defaults to the machine's native width


def main():
    repeat[3]("hello")
    var a = Vec[DType.float32, 4](SIMD[DType.float32, 4](1, 2, 3, 4))
    var b = Vec[DType.float32, 4](SIMD[DType.float32, 4](10))
    print("  dot =", a.dot(b))
    print("  sum f32 x native:", sum_simd(SIMD[DType.float32, simd_width_of[DType.float32]()](1)))
    print("  sum i8  x native:", sum_simd(SIMD[DType.int8, simd_width_of[DType.int8]()](1)))
