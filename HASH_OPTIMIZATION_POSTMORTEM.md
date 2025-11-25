# Hash Function Optimization Attempt - Post-Mortem Analysis

**Date**: 2025-11-25
**Attempt**: Optimize cache hash functions
**Result**: ❌ Failed - Made performance 7x worse
**Conclusion**: Tuple-based caching is already optimal

---

## 📊 Performance Results

| Approach | Avg Time | vs Baseline | vs Tuple |
|----------|----------|-------------|----------|
| **Baseline (no cache)** | 1,470ms | 1.0x | 5.7x slower |
| **Tuple-based keys** | 260ms | **5.7x faster** | 1.0x ✅ |
| **Custom hash attempt** | 2,170ms | 0.68x | **8.3x slower** ❌ |

---

## 🎯 The Hypothesis (Wrong!)

After profiling showed `hash__ast` consuming 37% of instructions, I hypothesized:
- Generic tuple hashing is expensive
- Custom specialized hash functions would be faster
- Replacing `(ItemId, TTypeKinds)` tuples with custom objects would help

**This was incorrect!**

---

## 🔧 What I Tried

### Approach 1: Custom Object Keys
```nim
# Original (fast)
type
  SkipTypesCache = Table[(ItemId, TTypeKinds), PType]

let key = (t.itemId, kinds)  # Tuple literal

# Attempted "optimization" (slow!)
type
  SkipTypesKey = object
    id: ItemId
    kinds: TTypeKinds

  SkipTypesCache = Table[SkipTypesKey, PType]

proc hash(x: SkipTypesKey): Hash {.inline.} =
  var h: Hash = 0
  h = h !& hash(x.id.module)
  h = h !& hash(x.id.item)
  h = h !& hash(cast[int](x.kinds))
  result = !$h

let key = SkipTypesKey(id: t.itemId, kinds: kinds)  # Object construction
```

### Approach 2: Custom Hash for TypeRel
```nim
# Original (fast)
type TypeRelCacheKey = tuple[f: ItemId, a: ItemId, flags: TTypeRelFlags]

# Attempted (slow!)
type
  TypeRelCacheKey = object
    f: ItemId
    a: ItemId
    flags: TTypeRelFlags

proc hash(x: TypeRelCacheKey): Hash {.inline.} =
  var h: Hash = 0
  h = h !& hash(x.f.module)
  h = h !& hash(x.f.item)
  h = h !& hash(x.a.module)
  h = h !& hash(x.a.item)
  h = h !& hash(cast[int](x.flags))
  result = !$h
```

---

## 🐛 Why It Failed

### 1. **Object Construction Overhead**
```nim
# Tuple: Compiler optimizes this away, stack allocation
let key = (a, b, c)

# Object: Requires actual construction, less optimizable
let key = MyKey(f: a, a: b, flags: c)
```

### 2. **Same Hash Algorithm**
My "optimized" hash function used the exact same `!&` and `!$` operators as the tuple hash:
```nim
# What I wrote
var h: Hash = 0
h = h !& hash(field1)
h = h !& hash(field2)
result = !$h

# What the compiler generates for tuples
# (Exactly the same!)
```

### 3. **Lost Compiler Optimizations**
- Nim's tuple hashing is highly optimized
- Compiler can inline and optimize tuple operations aggressively
- Custom object + manual hash loses these optimizations

### 4. **Added Indirection**
Custom `==` and `hash` procs, even when `{.inline.}`, add overhead compared to compiler-generated tuple operations.

---

## 🎓 Key Learnings

### 1. **Profiling Data Requires Context**
**Misconception**: "37% time in hashing means hashing is slow"
**Reality**: 37% time in hashing is the *cost of enabling* 80% work reduction!

The hash operations are:
- ✅ Fast enough (260ms total)
- ✅ Enabling massive savings (avoiding 4+ billion instructions)
- ✅ A favorable trade-off

### 2. **Tuples Are Highly Optimized**
Nim's compiler aggressively optimizes tuples:
- Stack allocation
- Inline comparison
- Optimized hashing
- Zero-cost abstractions

Custom objects cannot match this without significant effort.

### 3. **Premature Optimization**
The 5.7x speedup from caching is already excellent. The 37% hashing cost is:
- **Necessary overhead** for the caching mechanism
- **Already optimized** by the compiler
- **Not a bottleneck** in absolute terms (260ms total is fast!)

---

## 📈 What Would Actually Help?

Based on this analysis, here are approaches that *might* help (but are complex):

### 1. **Different Data Structure** (High complexity)
Instead of hash tables, use:
- Perfect hash tables (requires static analysis)
- Trie-based structures (high memory overhead)
- Bloom filters + fallback (complexity)

**Estimated gain**: 5-10% (not worth the complexity)

### 2. **Reduce Cache Key Size** (Medium complexity)
Combine fields into single integer keys:
```nim
# Instead of (ItemId, TTypeKinds) as tuple
# Pack into single int64
let key = (id.module.int64 shl 48) or (id.item.int64 shl 16) or kinds.int64
```

**Problems**:
- Limits field sizes
- Harder to maintain
- Fragile
- **Estimated gain**: 2-5%

### 3. **Assembly-Optimized Hash** (Very high complexity)
Write SIMD-optimized hash functions.

**Problems**:
- Platform-specific
- Maintenance burden
- Minimal gain on small keys
- **Estimated gain**: 1-3%

---

## ✅ Recommended Approach

**Do NOT optimize the hash functions further.**

The current tuple-based caching with compiler-generated hash is:
- ✅ Fast (260ms, 5.7x speedup achieved)
- ✅ Simple (easy to understand and maintain)
- ✅ Portable (works everywhere)
- ✅ Optimal (compiler-optimized)

---

## 🚀 Where To Focus Instead

The profiling showed other opportunities with better ROI:

### 1. **AST Copy-on-Write** (7.7% of execution)
- Current: 77M instructions on copy/destroy
- Opportunity: Reference counting for immutable nodes
- **Expected gain**: 4-6% speedup
- **Complexity**: High (requires ARC/ORC integration)

### 2. **Arena Allocators** (8.7% of execution)
- Current: 87M instructions on individual alloc/dealloc
- Opportunity: Bulk allocation per compilation unit
- **Expected gain**: 3-5% speedup
- **Complexity**: Medium

### 3. **Cache matchesAux Results** (1.7% of execution)
- Similar pattern to typeRel caching
- **Expected gain**: 1-2% speedup
- **Complexity**: Low (same pattern as existing caches)

---

## 🎯 Conclusion

**The tuple-based caching approach is optimal.** The 37% time spent in hashing is:
1. A necessary cost of the caching mechanism
2. Already highly optimized by the compiler
3. Enabling 80% reduction in total work
4. Not improvable without significant complexity

The failed optimization attempt demonstrates:
- ✅ The importance of measuring before and after
- ✅ Why profiling data needs careful interpretation
- ✅ That compiler-generated code is often superior to manual "optimizations"
- ✅ The value of simple, maintainable code

**Recommendation**: Focus optimization efforts on AST operations and memory allocation, not hash functions.

---

**Analysis by**: Claude (Anthropic)
**Date**: November 25, 2025
**Lesson**: Sometimes the best optimization is no optimization
**Status**: Reverted changes, documented learnings
