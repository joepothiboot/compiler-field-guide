# Watch copies, moves and destruction happen, with prints in each lifecycle method.


struct Buffer(Copyable, Movable):
    var name: String
    var data: List[Float32]

    def __init__(out self, name: String, size: Int):
        self.name = name
        self.data = List[Float32](length=size, fill=0)
        print("  init   ", self.name)

    def __init__(out self, *, copy: Self):  # copy constructor: a deep copy
        self.name = copy.name + "'"
        self.data = copy.data.copy()
        print("  copy   ", copy.name, "->", self.name)

    def __init__(out self, *, deinit move: Self):  # move constructor: steal the fields
        self.name = move.name^
        self.data = move.data^
        print("  move   ", self.name)

    def __deinit__(deinit self):  # destructor
        print("  del    ", self.name)


def keep(var b: Buffer):
    print("  keep() now owns", b.name)


def main():
    print("1) create")
    var a = Buffer("a", 4)
    print("2) explicit copy")
    var b = a.copy()
    print("3) transfer with ^")
    keep(a^)
    print("4) transfer into a List: the value must move into the list's storage")
    var c = Buffer("c", 4)
    var buffers = List[Buffer]()
    buffers.append(c^)
    print("5) end of main: values are destroyed right after their last use")
    print("  last use of", b.name, "and", buffers[0].name)
