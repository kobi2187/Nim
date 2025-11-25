# Benchmark: Macro and template expansion
import std/macros

template repeat(n: int, body: untyped) =
  for i in 0..<n:
    body

template withTiming(name: string, body: untyped) =
  block:
    let start = 0
    body
    let elapsed = 1
    echo name, ": ", elapsed

macro generateFields(count: static[int]): untyped =
  result = newStmtList()
  for i in 0..<count:
    result.add(newIdentDefs(ident("field" & $i), ident("int")))

macro generateProcs(count: static[int]): untyped =
  result = newStmtList()
  for i in 0..<count:
    let procName = ident("proc" & $i)
    let procBody = newStmtList(newLit(i))
    result.add(newProc(procName, [], procBody))

# Expand templates and macros
repeat 10:
  echo "iteration"

withTiming "test":
  var x = 42
  inc x

# This would generate compile-time code
# generateProcs(20)

type
  MyObject = object
    x: int
    y: string
    z: float

let obj = MyObject(x: 1, y: "test", z: 3.14)
echo obj
