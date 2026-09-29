# Summing 16M float32 values of 0.1 three ways. Reordering a float sum changes
# both the speed AND the result, which is why compilers won't do it unasked.
from std.time import perf_counter_ns

comptime N = 1 << 24
comptime W = 16  # 4 NEON registers of 4 floats


def sum_scalar(x: List[Float32]) -> Float32:
    var p = x.unsafe_ptr()
    var s: Float32 = 0
    for i in range(N):
        s += p[unsafe_offset=i]  # one long dependency chain, in order
    return s


def sum_simd(x: List[Float32]) -> Float32:
    var p = x.unsafe_ptr()
    var acc = SIMD[DType.float32, W](0)  # 16 independent partial sums
    for i in range(0, N, W):
        acc += p.unsafe_load[width=W](i)
    return acc.reduce_add()  # combine the lanes once, at the end


def sum_f64(x: List[Float32]) -> Float64:
    var p = x.unsafe_ptr()
    var s: Float64 = 0
    for i in range(N):
        s += Float64(p[unsafe_offset=i])
    return s


def main():
    var x = List[Float32](length=N, fill=0.1)
    for _ in range(2):  # second round is warm
        var t0 = perf_counter_ns()
        var a = sum_scalar(x)
        var t1 = perf_counter_ns()
        var b = sum_simd(x)
        var t2 = perf_counter_ns()
        var c = sum_f64(x)
        print("scalar f32:", a, " ", (t1 - t0) // 1_000_000, "ms")
        print("simd   f32:", b, " ", (t2 - t1) // 1_000_000, "ms")
        print("float64   :", c)
