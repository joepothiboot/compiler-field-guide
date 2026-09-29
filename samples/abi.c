struct Pair { long a; long b; };
struct Big { long v[4]; };

long add3(long x, long y, long z) { return x + y + z; }
double scale(double x, int n) { return x * n; }
struct Pair make_pair(long a, long b) { struct Pair p = {a, b}; return p; }
long sum_big(struct Big big) { return big.v[0] + big.v[3]; }
long call_add3(void) { return add3(1, 2, 3) + 10; }
