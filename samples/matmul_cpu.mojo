# C = A x B for NxN float32 matrices, timed on the CPU, from naive to fast:
#   1. naive (i, j, k)             B walked down a column
#   2. interchanged (i, k, j)      innermost loop contiguous
#   3. cache-tiled (sweep T)       a textbook tiling; barely helps on this M2
#   4. register-blocked SIMD       a 4x16 tile of C kept in registers
#   5. register-blocked + k-blocks the B panel stays in cache across rows
#   6. fused relu epilogue vs. a separate relu pass
# Runs at N = 512 (fits in the M2's 16 MiB L2) and N = 2048 (does not).
from std.time import perf_counter_ns

comptime NR = 16  # columns of C per register block (4 NEON registers of 4 floats)
comptime MR = 4  # rows of C per register block


def matmul_naive[N: Int](a: List[Float32], b: List[Float32], mut c: List[Float32]):
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()
    for i in range(N):
        for j in range(N):
            var acc: Float32 = 0
            for k in range(N):
                acc += pa[unsafe_offset=i * N + k] * pb[unsafe_offset=k * N + j]
            pc[unsafe_offset=i * N + j] = acc


def matmul_ikj[N: Int](a: List[Float32], b: List[Float32], mut c: List[Float32]):
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()
    for i in range(N):
        for k in range(N):
            var aik = pa[unsafe_offset=i * N + k]
            for j in range(N):
                pc[unsafe_offset=i * N + j] += aik * pb[unsafe_offset=k * N + j]


def matmul_tiled[N: Int, T: Int](a: List[Float32], b: List[Float32], mut c: List[Float32]):
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()
    for ii in range(0, N, T):
        for kk in range(0, N, T):
            for jj in range(0, N, T):
                for i in range(ii, ii + T):
                    for k in range(kk, kk + T):
                        var aik = pa[unsafe_offset=i * N + k]
                        for j in range(jj, jj + T):
                            pc[unsafe_offset=i * N + j] += aik * pb[unsafe_offset=k * N + j]


def matmul_regblock[N: Int, KC: Int](a: List[Float32], b: List[Float32], mut c: List[Float32]):
    # For each 4x16 block of C: load it into 4 SIMD accumulators, run the k loop
    # entirely in registers, store once. KC = N means no k-blocking.
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()
    for kk in range(0, N, KC):
        for j0 in range(0, N, NR):
            for i0 in range(0, N, MR):
                var acc0 = pc.unsafe_load[width=NR]((i0 + 0) * N + j0)
                var acc1 = pc.unsafe_load[width=NR]((i0 + 1) * N + j0)
                var acc2 = pc.unsafe_load[width=NR]((i0 + 2) * N + j0)
                var acc3 = pc.unsafe_load[width=NR]((i0 + 3) * N + j0)
                for k in range(kk, kk + KC):
                    var bv = pb.unsafe_load[width=NR](k * N + j0)  # one row of the B panel
                    acc0 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 0) * N + k]) * bv
                    acc1 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 1) * N + k]) * bv
                    acc2 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 2) * N + k]) * bv
                    acc3 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 3) * N + k]) * bv
                pc.unsafe_store((i0 + 0) * N + j0, acc0)
                pc.unsafe_store((i0 + 1) * N + j0, acc1)
                pc.unsafe_store((i0 + 2) * N + j0, acc2)
                pc.unsafe_store((i0 + 3) * N + j0, acc3)


def relu_inplace[N: Int](mut c: List[Float32]):
    var pc = c.unsafe_ptr()
    for i in range(N * N):
        var v = pc[unsafe_offset=i]
        pc[unsafe_offset=i] = 0 if v < 0 else v


def matmul_regblock_relu[N: Int](a: List[Float32], b: List[Float32], mut c: List[Float32]):
    # Register-blocked, no k-blocking, with relu applied to the accumulators
    # before the single store: the epilogue costs no extra memory traffic.
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()
    var zero = SIMD[DType.float32, NR](0)
    for j0 in range(0, N, NR):
        for i0 in range(0, N, MR):
            var acc0 = SIMD[DType.float32, NR](0)
            var acc1 = SIMD[DType.float32, NR](0)
            var acc2 = SIMD[DType.float32, NR](0)
            var acc3 = SIMD[DType.float32, NR](0)
            for k in range(N):
                var bv = pb.unsafe_load[width=NR](k * N + j0)
                acc0 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 0) * N + k]) * bv
                acc1 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 1) * N + k]) * bv
                acc2 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 2) * N + k]) * bv
                acc3 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 3) * N + k]) * bv
            pc.unsafe_store((i0 + 0) * N + j0, acc0.lt(zero).select(zero, acc0))
            pc.unsafe_store((i0 + 1) * N + j0, acc1.lt(zero).select(zero, acc1))
            pc.unsafe_store((i0 + 2) * N + j0, acc2.lt(zero).select(zero, acc2))
            pc.unsafe_store((i0 + 3) * N + j0, acc3.lt(zero).select(zero, acc3))


def zero[N: Int](mut c: List[Float32]):
    for i in range(N * N):
        c[i] = 0


def max_diff[N: Int](x: List[Float32], y: List[Float32]) -> Float32:
    var m: Float32 = 0
    for i in range(N * N):
        m = max(m, abs(x[i] - y[i]))
    return m


def ms(t0: Int, t1: Int) -> Float64:
    return Float64(t1 - t0) / 1_000_000


def run[N: Int](with_naive: Bool):
    var a = List[Float32](length=N * N, fill=0)
    var b = List[Float32](length=N * N, fill=0)
    for i in range(N * N):  # deterministic values in [-1, 1)
        a[i] = Float32((i * 7919) % 2000) / 1000 - 1
        b[i] = Float32((i * 104729) % 2000) / 1000 - 1
    var expected = List[Float32](length=N * N, fill=0)
    var c = List[Float32](length=N * N, fill=0)

    print("--- N =", N)
    var t0 = perf_counter_ns()
    if with_naive:
        matmul_naive[N](a, b, expected)
    else:  # naive is too slow at this size; (i,k,j) is the reference
        matmul_ikj[N](a, b, expected)
    var t1 = perf_counter_ns()
    if with_naive:
        print("1  naive (i,j,k)           ", ms(t0, t1), "ms")

    zero[N](c)
    t0 = perf_counter_ns()
    matmul_ikj[N](a, b, c)
    t1 = perf_counter_ns()
    print("2  interchanged (i,k,j)    ", ms(t0, t1), "ms   diff:", max_diff[N](c, expected))

    comptime for t in range(4):  # unrolled at compile time: T = 16, 32, 64, 128
        comptime T = 16 << t
        zero[N](c)
        t0 = perf_counter_ns()
        matmul_tiled[N, T](a, b, c)
        t1 = perf_counter_ns()
        print("3  cache-tiled T =", T, "     ", ms(t0, t1), "ms   diff:", max_diff[N](c, expected))

    zero[N](c)
    t0 = perf_counter_ns()
    matmul_regblock[N, N](a, b, c)
    t1 = perf_counter_ns()
    print("4  register-blocked        ", ms(t0, t1), "ms   diff:", max_diff[N](c, expected))

    comptime for t in range(3):  # KC = 64, 128, 256
        comptime KC = 64 << t
        zero[N](c)
        t0 = perf_counter_ns()
        matmul_regblock[N, KC](a, b, c)
        t1 = perf_counter_ns()
        print("5  reg-blocked, KC =", KC, "  ", ms(t0, t1), "ms   diff:", max_diff[N](c, expected))

    zero[N](c)
    t0 = perf_counter_ns()
    matmul_regblock[N, N](a, b, c)
    relu_inplace[N](c)
    t1 = perf_counter_ns()
    var separate = c.copy()
    print("6a reg-blocked + relu pass ", ms(t0, t1), "ms")

    zero[N](c)
    t0 = perf_counter_ns()
    matmul_regblock_relu[N](a, b, c)
    t1 = perf_counter_ns()
    print("6b reg-blocked, fused relu ", ms(t0, t1), "ms   diff vs 6a:", max_diff[N](c, separate))


def main():
    run[512](with_naive=True)
    run[2048](with_naive=False)
