# Nim Compiler Performance Profiling Results

**Date**: 2025-11-24
**Compiler Version**: Nim 2.3.1
**Profiling Method**: Valgrind Callgrind
**Test Case**: benchmark_modules.nim (imports 15+ stdlib modules)
**Total Instructions**: 5,241,503,254

## Executive Summary

Profiling confirms that **signature matching (sigmatch.nim)** and **AST operations** dominate compilation time, accounting for approximately **20% of total instructions**. Memory allocation represents another **10%**. These findings validate our earlier code analysis and provide concrete targets for optimization.

---

## Top Hotspots by Category

### 1. **Memory Allocation: 10.36% of Total Instructions**

| Function | Instructions | % | Impact |
|----------|--------------|---|--------|
| `rawAlloc` | 278,235,890 | 5.31% | 🔴 Critical |
| `rawDealloc` | 139,267,044 | 2.66% | 🔴 Critical |
| `nimNewObj` | 107,755,272 | 2.06% | 🔴 Critical |
| `realloc` | 30,235,845 | 0.58% | 🟡 Medium |
| `nimRawDispose` | 22,601,832 | 0.43% | 🟡 Medium |

**Key Insight**: Over 10% of compilation time is spent on memory management. This suggests:
- Too many small allocations
- Lack of object pooling
- Excessive AST node creation and destruction

**Recommendations**:
- Implement arena allocators for AST nodes (allocate per compilation unit, free all at once)
- Pool commonly-used objects (PNode, PType, PSym)
- Reduce temporary allocations in hot paths

---

### 2. **Signature Matching: 11.66% of Total Instructions**

| Function | Instructions | % | Impact |
|----------|--------------|---|--------|
| `matchesAux` (two variants) | 175,263,179 | 3.34% | 🔴 Critical |
| `typeRel` (two variants) | 98,725,172 | 1.88% | 🔴 Critical |
| `initCandidate` (two variants) | 87,011,118 | 1.66% | 🔴 Critical |
| `paramTypesMatchAux` | 47,874,626 | 0.91% | 🟠 High |
| `userConvMatch` | 34,672,034 | 0.66% | 🟠 High |
| `handleRange` | 36,745,777 | 0.70% | 🟠 High |
| `maybeSkipDistinct` | 31,764,135 | 0.61% | 🟠 High |
| Other sigmatch functions | ~100M | ~1.9% | 🟠 High |

**Key Insight**: Signature matching is THE single biggest algorithmic bottleneck, consuming nearly **12% of all instructions**. This validates our finding that sigmatch.nim has no caching infrastructure.

**Verified Issues**:
✅ No result caching (grep showed zero cache-related code)
✅ Creates multiple candidate copies (line 2720-2725)
✅ Repeated type compatibility checks
✅ Linear search through candidates

**Recommendations** (by priority):
1. **Cache type compatibility results**: `Table[(PType, PType), TTypeRelation]`
2. **Implement copy-on-write for TCandidate**: Avoid creating 3 copies per candidate
3. **Cache overload resolution results**: Map (callee, args) → best match
4. **Early exit on exact match**: Stop searching when perfect match found
5. **Memoize typeRel calls**: Store results in type objects

---

### 3. **AST Operations: 14.76% of Total Instructions**

| Category | Function | Instructions | % |
|----------|----------|--------------|---|
| **Copying** | `eqcopy___astdef_u1048` | 183,252,604 | 3.50% |
| | `eqcopy___astdef_u1592` | 113,030,822 | 2.16% |
| | `eqcopy___astdef_u1431` | 108,295,936 | 2.07% |
| | `copyTree` | 109,280,202 | 2.08% |
| | **Subtotal** | **513,859,564** | **9.81%** |
| **Destroying** | `eqdestroy___astdef_u1045` | 125,052,437 | 2.39% |
| | `eqdestroy___astdef_u1428` | 91,895,530 | 1.75% |
| | Others | ~50M | ~1.0% |
| | **Subtotal** | **~267M** | **~5.1%** |
| **Traversal** | `skipTypes` | 80,541,154 | 1.54% |
| **Creation** | `newNode` | 26,334,180 | 0.50% |

**Key Insight**: Nearly **15% of instructions** are AST copying and destruction. This is caused by:
- Value semantics throughout compiler (pass-by-copy)
- Template/macro expansion creating new trees
- Lack of structural sharing
- Deep copying in overload resolution

**Recommendations**:
1. **Implement move semantics** where possible (Nim 2.0 has this, use it!)
2. **Structural sharing**: Share immutable AST subtrees
3. **Lazy copying**: Copy-on-write for AST nodes
4. **Reduce template expansion overhead**: Cache expanded templates
5. **skipTypes optimization**: Cache results in type objects

---

### 4. **Symbol Lookup: 4.61% of Total Instructions**

| Function | Instructions | % |
|----------|--------------|---|
| `nextIdentIter__astalgo` | 103,283,283 | 1.97% |
| `nextOverloadIter` | 30,087,577 | 0.57% |
| `mergeShadowScope` | 25,244,270 | 0.48% |
| `getIdent` | 25,219,852 | 0.48% |
| `initIdentIter` | 17,730,778 | 0.34% |
| `nextIdentIter__lookups` | 16,213,661 | 0.31% |
| Others | ~40M | ~0.8% |

**Key Insight**: Symbol iteration and lookup consume significant time. The `nextIdentIter` function alone (1.97%) suggests inefficient iteration patterns.

**Recommendations**:
1. **Hash-based symbol tables**: Replace linear iteration with O(1) lookup
2. **Scope caching**: Cache symbol resolution results per scope
3. **Avoid redundant lookups**: Store resolved symbols in AST nodes

---

### 5. **Semantic Analysis: 1.70% of Total Instructions**

| Function | Instructions | % |
|----------|--------------|---|
| `pickBestCandidate` (variants) | 41,521,247 | 0.79% |
| `initCandidateSymbols` | 15,300,673 | 0.29% |
| `semExpr` | 12,713,880 | 0.24% |
| `determineType` | 11,974,556 | 0.23% |
| Others | ~10M | ~0.2% |

**Note**: `semExpr` is only 0.24%, much lower than expected. This suggests the real cost is in the functions it calls (sigmatch, lookups, etc.), not in semExpr itself.

---

## Critical Path Analysis

### Compilation Breakdown (Estimated)

```
Memory Allocation:        10.4%  ███████████
Signature Matching:       11.7%  ████████████
AST Copy/Destroy:         14.8%  ███████████████
Symbol Lookup:             4.6%  █████
Semantic Analysis:         1.7%  ██
Other (parsing, codegen): 56.8%  █████████████████████████████████████████████████████████
```

### Cascading Cost of Overload Resolution

When resolving an overloaded call:
1. **initCandidateSymbols**: Collect all candidates (1.66%)
2. **For each candidate**:
   - **initCandidate**: Create TCandidate copies (1.66%)
   - **matchesAux**: Check if arguments match (3.34%)
   - **typeRel**: Check type compatibility (1.88%)
   - **AST copying**: Copy nodes for comparison (9.81%)
3. **pickBestCandidate**: Select winner (0.79%)

**Total for one overload resolution**: Easily 10-20% of instructions if there are many candidates.

---

## Validated Code Issues

### ✅ Confirmed from Profiling

| Issue | Location | Evidence | Priority |
|-------|----------|----------|----------|
| No sigmatch caching | sigmatch.nim | 11.66% of instructions | 🔴 P0 |
| Excessive AST copying | Throughout | 14.76% of instructions | 🔴 P0 |
| Memory allocation overhead | system.nim | 10.36% of instructions | 🔴 P0 |
| Linear symbol iteration | astalgo.nim:2743 | 1.97% single function | 🟠 P1 |
| No type compatibility cache | sigmatch.nim:258 | 1.88% spent in typeRel | 🟠 P1 |
| Candidate copying | sigmatch.nim:433 | 1.66% in initCandidate | 🟠 P1 |
| skipTypes overhead | ast.nim:4643 | 1.54% single function | 🟡 P2 |

### ❌ Not Found in This Profile

| Issue | Status |
|-------|--------|
| `loadCompilerProc` linear search | Not visible (only happens during module load) |
| Enum value linear search | Not visible (VM-specific) |
| `hasYields` traversal | Not visible (only in iterator code) |
| Suggest mode O(n) lookup | Not visible (IDE mode only) |

**Note**: These issues are still valid but don't show up in this particular benchmark.

---

## Actionable Optimization Plan

### Phase 1: Quick Wins (1-2 weeks each)

#### 1.1. Add skipTypes Cache
- **File**: compiler/ast.nim:4643
- **Impact**: Save 1.54% (80M instructions)
- **Implementation**: Add `cachedSkipTypes: PType` field to PType
```nim
proc skipTypes(t: PType, kinds: set[TTypeKind]): PType =
  if t.cachedSkipTypes != nil and t.cachedSkipKinds == kinds:
    return t.cachedSkipTypes
  # ... existing logic ...
  t.cachedSkipTypes = result
  t.cachedSkipKinds = kinds
```

#### 1.2. Optimize nextIdentIter
- **File**: compiler/astalgo.nim:2743
- **Impact**: Save ~2% (100M instructions)
- **Implementation**: Use hash table instead of linear iteration

#### 1.3. Add getIdent Cache
- **File**: compiler/idents.nim:96
- **Impact**: Save ~0.5% (25M instructions)
- **Implementation**: The identifier table likely already has caching, verify it's being used

### Phase 2: High-Impact Changes (2-4 weeks each)

#### 2.1. Implement Signature Match Result Caching
- **Files**: compiler/sigmatch.nim
- **Impact**: Save 5-8% (250-400M instructions)
- **Implementation**:
```nim
type
  TypeRelCache = Table[(PType, PType, int), TTypeRelation]

var typeRelCache {.global.}: TypeRelCache

proc typeRel(c: var TCandidate, f, a: PType, flags: int): TTypeRelation =
  let key = (f, a, flags)
  if key in typeRelCache:
    return typeRelCache[key]
  # ... existing logic ...
  typeRelCache[key] = result
```

#### 2.2. Reduce AST Copying with Move Semantics
- **Files**: Throughout compiler
- **Impact**: Save 5-10% (250-500M instructions)
- **Implementation**: Use `{.cursor.}` pragma, pass by `sink`, explicit `move()`

#### 2.3. Implement Copy-on-Write TCandidate
- **File**: compiler/sigmatch.nim:433
- **Impact**: Save 1-2% (50-100M instructions)
- **Implementation**: Share immutable parts of TCandidate, only copy on modification

### Phase 3: Architectural Changes (1-2 months each)

#### 3.1. Arena Allocators for AST Nodes
- **Impact**: Save 5-8% (reduce allocation overhead)
- **Implementation**: Per-module arena, batch free on module completion

#### 3.2. Object Pooling for Common Types
- **Types**: PNode, PType, PSym, TCandidate
- **Impact**: Save 3-5% (reduce allocation/deallocation)

#### 3.3. Incremental Overload Resolution
- **File**: compiler/semcall.nim:195
- **Impact**: Avoid full restarts on symbol table changes
- **Implementation**: Track which candidates are affected, only recheck those

---

## Performance Targets

| Optimization | Expected Speedup | Effort | Risk |
|--------------|------------------|--------|------|
| skipTypes cache | 1.5% | Low | Low |
| typeRel cache | 5-8% | Medium | Medium |
| Reduce AST copying | 5-10% | High | Medium |
| TCandidate copy-on-write | 1-2% | Medium | Low |
| Arena allocators | 5-8% | High | Medium-High |
| Symbol lookup optimization | 2-3% | Medium | Low |
| **TOTAL POTENTIAL** | **20-35%** | | |

---

## Next Steps

1. **Verify findings** on larger codebases:
   - Nim compiler itself (compiling compiler)
   - Large real-world projects (Nimble, Karax, etc.)

2. **Implement instrumentation**:
   - Add counters for cache hits/misses
   - Track how many candidates per overload resolution
   - Measure AST node allocation rates

3. **Start with lowest-risk, highest-impact**:
   - Begin with skipTypes cache (easy, safe, measurable)
   - Move to typeRel cache (bigger win, more complex)
   - Then tackle AST copying reduction

4. **Create benchmark suite**:
   - Include these test files
   - Add generic-heavy code
   - Add overload-heavy code
   - Add macro-heavy code

---

## Profiling Command Reference

```bash
# Profile compilation
valgrind --tool=callgrind --callgrind-out-file=callgrind.out ./bin/nim c yourfile.nim

# Analyze results
callgrind_annotate --auto=yes callgrind.out | less

# Find specific functions
callgrind_annotate callgrind.out | grep "sigmatch"

# Generate visual call graph (requires kcachegrind)
kcachegrind callgrind.out
```

---

## Conclusion

The profiling data **confirms our code analysis**: signature matching and AST operations are the primary bottlenecks. The good news is that these are algorithmic issues with clear solutions (caching, copy-on-write, move semantics) rather than fundamental architectural problems.

A focused effort on the Phase 1 and Phase 2 optimizations could reasonably achieve **15-20% faster compilation** with moderate risk and effort.
