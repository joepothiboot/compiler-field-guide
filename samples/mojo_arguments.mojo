# Argument conventions: read (default), mut, var (owned), out.

def show(x: List[Int]):  # read: borrowed, immutable, no copy
    print("  read:", len(x), "items")


def append_one(mut x: List[Int]):  # mut: borrowed, mutable; caller sees changes
    x.append(1)


def consume(var x: List[Int]) -> Int:  # var: this function owns its own value
    x.append(99)  # allowed: it is ours
    return len(x)


def make_list(out result: List[Int]):  # out: initialize the caller's result slot
    result = [7, 8, 9]


struct Counter(Movable):
    var count: Int

    def __init__(out self):  # constructors initialize `self` through `out`
        self.count = 0

    def bump(mut self):  # methods that mutate take `mut self`
        self.count += 1

    def get(self) -> Int:  # read-only methods take plain `self`
        return self.count


def main():
    var xs: List[Int] = [1, 2, 3]
    show(xs)
    append_one(xs)
    print("after mut:", len(xs))
    print("consume a copy:", consume(xs.copy()), " original still:", len(xs))
    print("consume by transfer:", consume(xs^))  # xs is moved; using it now is an error
    var ys = make_list()
    print("out result:", len(ys))
    var c = Counter()
    c.bump()
    c.bump()
    print("counter:", c.get())
