# Benchmark: Module imports and dependencies
import std/[
  tables, sets, sequtils, strutils, algorithm, sugar,
  math, os, strformat, json, options, parseutils,
  hashes, random, bitops, unicode, base64
]

type
  ComplexData = object
    id: int
    name: string
    values: seq[float]
    metadata: Table[string, JsonNode]
    tags: HashSet[string]

proc processData(data: ComplexData): string =
  let avgValue = if data.values.len > 0:
    data.values.sum / data.values.len.float
  else:
    0.0

  &"Data {data.name}: avg={avgValue:.2f}, tags={data.tags.len}"

let sample = ComplexData(
  id: 1,
  name: "test",
  values: @[1.0, 2.0, 3.0],
  metadata: {"key": %"value"}.toTable,
  tags: ["tag1", "tag2"].toHashSet
)

echo processData(sample)
