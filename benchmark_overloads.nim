# Benchmark: Heavy overload resolution
import std/strutils

proc process(x: int): string = $x
proc process(x: float): string = $x
proc process(x: string): string = x
proc process(x: bool): string = $x
proc process(x: char): string = $x
proc process[T](x: seq[T]): string = $x.len
proc process[T](x: openArray[T]): string = $x.len
proc process[K, V](x: (K, V)): string = $x[0] & ":" & $x[1]

proc transform(x: int): int = x * 2
proc transform(x: float): float = x * 2.0
proc transform(x: string): string = x & x
proc transform[T](x: seq[T]): seq[T] = x & x
proc transform[T](x: openArray[T]): seq[T] = @x & @x

proc combine(a, b: int): int = a + b
proc combine(a, b: float): float = a + b
proc combine(a, b: string): string = a & b
proc combine[T](a, b: seq[T]): seq[T] = a & b
proc combine[T](a: T, b: T): T = a

# Create lots of overload resolution opportunities
let x1 = process(42)
let x2 = process(3.14)
let x3 = process("hello")
let x4 = process(true)
let x5 = process('c')
let x6 = process(@[1, 2, 3])
let x7 = process([1, 2, 3, 4])

let y1 = transform(10)
let y2 = transform(2.5)
let y3 = transform("test")
let y4 = transform(@[1, 2])
let y5 = transform([3, 4, 5])

let z1 = combine(1, 2)
let z2 = combine(1.0, 2.0)
let z3 = combine("a", "b")
let z4 = combine(@[1], @[2])

echo x1, x2, x3, x4, x5, x6, x7
echo y1, y2, y3, y4.len, y5.len
echo z1, z2, z3, z4.len
