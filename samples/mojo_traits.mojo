# A trait is a compile-time interface. Generic code is specialized per type.


trait Shape:
    def area(self) -> Float64:
        ...

    def name(self) -> String:
        ...


@fieldwise_init
struct Square(Copyable, Shape):
    var side: Float64

    def area(self) -> Float64:
        return self.side * self.side

    def name(self) -> String:
        return "square"


@fieldwise_init
struct Circle(Copyable, Shape):
    var radius: Float64

    def area(self) -> Float64:
        return 3.141592653589793 * self.radius * self.radius

    def name(self) -> String:
        return "circle"


def describe[T: Shape](s: T):  # compiled once for Square, once for Circle
    print(" ", s.name(), "area =", s.area())


def total_area[T: Shape & Copyable](items: List[T]) -> Float64:
    var total = 0.0
    for item in items:
        total += item.area()
    return total


def main():
    describe(Square(2.0))
    describe(Circle(1.0))
    var squares: List[Square] = [Square(1.0), Square(2.0), Square(3.0)]
    print("  total area of squares =", total_area(squares))
