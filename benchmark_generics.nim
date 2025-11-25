# Benchmark: Heavy generic instantiation
import std/tables

type
  GenericContainer[T] = object
    data: seq[T]
    metadata: Table[string, T]

  NestedGeneric[A, B] = object
    first: GenericContainer[A]
    second: GenericContainer[B]
    combined: Table[A, B]

proc newContainer[T](): GenericContainer[T] =
  result.data = @[]
  result.metadata = initTable[string, T]()

proc add[T](c: var GenericContainer[T], item: T, key: string = "") =
  c.data.add(item)
  if key.len > 0:
    c.metadata[key] = item

proc process[A, B](n: NestedGeneric[A, B]): int =
  result = n.first.data.len + n.second.data.len

# Instantiate many generic types
var c1 = newContainer[int]()
var c2 = newContainer[string]()
var c3 = newContainer[float]()
var c4 = newContainer[bool]()
var c5 = newContainer[seq[int]]()
var c6 = newContainer[Table[string, int]]()

c1.add(42, "answer")
c2.add("hello", "greeting")
c3.add(3.14, "pi")
c4.add(true, "bool")
c5.add(@[1, 2, 3], "nums")

var nested1: NestedGeneric[int, string]
var nested2: NestedGeneric[float, bool]
var nested3: NestedGeneric[string, int]

echo process(nested1)
echo process(nested2)
echo process(nested3)
