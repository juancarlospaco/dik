## * Table implemented as optimized sorted hashed dictionary of `{array[char]: Option[T]}`, same size and API as a Table, 0 dependencies, ~300 lines.
## .. image:: https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Madoqua_kirkii_-_female_%28Namutoni%29.jpg/1200px-Madoqua_kirkii_-_female_%28Namutoni%29.jpg
import hashes, options, bitops

type
  Indices = distinct pointer  # ptr int

  Item[T] = ref object
    hash: uint32
    key:  array[32, char]  # Instead of T, use array[char], but users interact via string
    val:  Option[T]        # Value can be anything, even Nullish values.

  Dik*[T] = object
    allocated, cap, len: uint32 ## `cap` and `len` are similar to `string` implementation.
    items: seq[Item[T]]         ## `seq` of `Option[T]`.
    indices: Indices            ## `pointer`

func arrai(str: string): array[32, char] {.inline.} =
  for i, c in str: result[i] = c

func str(arrai: array[32, char]): string {.inline, noinit.} =
  result = newStringOfCap(32)
  for c in arrai:
    if c != '\x00': result.add c

iterator pairs*[T](self: Dik[T]): (string, Option[T]) =
  runnableExamples("--gc:arc --experimental:strictFuncs --import:std/options"):
    for (key, value) in {"key": "value"}.toDik.pairs: doAssert key == "key" and value.get == "value"
  for it in self.items:
    if it != nil: yield (it.key.str, it.val)

iterator keys*[T](self: Dik[T]): string =
  runnableExamples("--gc:arc --experimental:strictFuncs "):
    for (key, value) in {"key": "value"}.toDik.pairs: doAssert key == "key"
  for it in self.items:
    if it != nil: yield it.key.str

iterator values*[T](self: Dik[T]): Option[T] =
  runnableExamples("--gc:arc --experimental:strictFuncs --import:std/options"):
    for value in {"key": "value"}.toDik.values: doAssert value.get == "value"
  for it in self.items:
    if it != nil: yield it.val

func `$`*[T](self: Dik[T]): string {.noinit.} =
  runnableExamples("--gc:arc --experimental:strictFuncs"): doAssert $toDik({"key": 666, "other": 42}) == """{"key":666,"other":42}"""
  result = "{"
  if unlikely(self.len == 0): result.add ':'
  else:
    for key, val in self.pairs:
      if result.len > 1: result.add ','
      result.add '"'
      result.add key
      result.add '"'
      result.add ':'
      result.add $(val.get)
  result.add '}'

func pretty*[T](self: Dik[T]): string =
  result = "{"
  if unlikely(self.len == 0): result.add ':'
  else:
    result.add '\n'
    for key, val in self.pairs:
      result.add ' '
      result.add ' '
      result.add '"'
      result.add key
      result.add '"'
      result.add ':'
      result.add '\t'
      result.add $(val.get)
      result.add ','
      result.add '\n'
  result.add '}'

func toCsv*[T](self: Dik[T]): string =
  runnableExamples("--gc:arc --experimental:strictFuncs"): doAssert {"key": 666, "other": 42}.toDik.toCsv == "\"key\",\"other\"\n\"666\",\"42\"\n"
  if unlikely(self.len == 0): return
  else:
    var i = 1
    for key in self.keys:
      result.addQuoted key
      result.add(if i == self.items.len: '\n' else: ',')
      inc i
    i = 1
    for val in self.values:
      result.addQuoted $(val.get)
      result.add(if i == self.items.len: '\n' else: ',')
      inc i

template clearDikImpl(self) =
  self.allocated = 0.uint32
  self.cap = 0.uint32
  self.len = 0.uint32
  self.items.setLen 0

proc clear*[T](self: var Dik[T]) {.inline.} =
  runnableExamples("--gc:arc --experimental:strictFuncs"):
    var dict: Dik[int] = {"key": 666, "other": 42}.toDik
    dict.clear()
    doAssert $dict == "{:}" and dict.len == 0
  clearDikImpl(self)
  self.resized(32)

proc `=destroy`*[T](self: var Dik[T]) =
  clearDikImpl(self)
  if likely(self.indices.pointer != nil): dealloc self.indices.pointer
  self.indices = Indices(nil)

func `==`*[T](lhs, rhs: Dik[T]): bool =
  runnableExamples("--gc:arc --experimental:strictFuncs"):
    let a = {"foo": 1, "bar": 2}.toDik
    let b = {"foo": 1, "bar": 2}.toDik
    var c = {"foo": 1, "OwO": 666, "bar": 2}.toDik
    doAssert a == b
    doAssert a != c
    c.del "OwO"
    doAssert a == c
  if lhs.len != rhs.len: return false
  var i0, i1: int
  while i0 < lhs.items.len and i1 < rhs.items.len:
    while lhs.items[i0] == nil: inc i0
    while rhs.items[i1] == nil: inc i1
    if lhs.items[i0][] != rhs.items[i1][]: return false
    inc i0
    inc i1
  result = true

func memset(p: pointer, v: cint, s: SomeInteger or csize_t): pointer {.importc, header: "string.h", discardable.}

func findEmptySlot[T](self: Dik[T], hashish: uint32): int =
  var i = hashish.int and int(self.allocated - 1)
  while on:
    if self.indices[i] == -1: return i
    i = (((i * 5) + 1) and int(self.allocated - 1))
  doAssert false, "ERROR: Slot not found"

proc resized*[T](self: var Dik[T], newSize: Positive) =
  runnableExamples("--gc:arc --experimental:strictFuncs"):
    var dict: Dik[int] = {"key": 666, "other": 42}.toDik
    doAssert dict.cap == 2   ## Capacity is "Read-Only".
    dict.resized(8)
    doAssert dict.cap == 10  ## (2 + 8)  ==  10
  assert newSize >= 0, "newSize must be a non-negative integer"
  let newCap = 1 shl (1 + fastLog2(((newSize * 3) + 1) shr 1))
  let itemSize: 1..8 =
    if newCap <= 0xff: 1
    elif newCap <= 0xffff: 2
    elif newCap <= 0xffffffff: 4
    else: 8
  let hasDeletedItems = self.len != self.cap
  self.allocated = newCap.uint32
  self.cap = uint32((newCap shl 1) div 3)
  self.indices = Indices(realloc(self.indices.pointer, itemSize * newCap))
  memset(self.indices.pointer, -1, itemSize * newCap)
  if hasDeletedItems:
    let oldItems = self.items
    self.items = newSeqOfCap[type(self.items[0])](self.len)
    for it in oldItems:
      if it != nil: self.items.add(it)
  for i, it in self.items:
    let i1 = self.findEmptySlot(it.hash.uint32)
    self.indices[i1] = i

proc newDik*[T](): Dik[T] {.inline.} = result.resized(32)

proc newDikOfCap*[T](capacity: Positive): Dik[T] {.inline.} = result.resized(capacity)

proc toDik*[T](items: openArray[(string, T)]): Dik[T] =
  runnableExamples("--gc:arc --experimental:strictFuncs"): doAssert {"key": 666, "other": 42}.toDik is Dik[int]
  assert items.len > 0, "items must not be empty openArray"
  result = newDikOfCap[T](items.len)
  for x in items: result[x[0]] = x[1]

func lookup[T](self: Dik[T], key: string, h: int): (int, int) =
  assert key.len > 0, "key must not be empty string"
  let key = arrai(key)
  let hashish = self.allocated - 1.uint32
  var i = h and hashish.int
  while on:
    let idx = self.indices[i]
    if idx == -1: return (i, idx)
    elif idx != -2:
      if self.items[idx].hash == h.uint32 and self.items[idx].key == key:
        return (i, idx)
    i = (((i * 5) + 1) and hashish.int)
  doAssert false, "ERROR: Dik item not found"

func contains*[T](self: Dik[T], key: string): bool =
  runnableExamples("--gc:arc --experimental:strictFuncs"): doAssert {"key": "value"}.toDik.contains "key"
  assert key.len > 0, "key must not be empty string"
  if self.allocated < 1: return false
  result = self.lookup(key, hash(key))[1] >= 0

func del*[T](self: var Dik[T], key: string) =
  runnableExamples("--gc:arc --experimental:strictFuncs"):
    var dict: Dik[string] = {"key": "value"}.toDik
    dict.del "key"
    doAssert dict.len == 0
  assert key.len > 0, "key must not be empty string"
  if self.allocated < 1: return
  let (i1, i2) = self.lookup(key, hash(key))
  if i2 < 0: return
  self.items[i2] = nil
  self.indices[i1] = -2
  self.len.dec

proc add*[T](self: var Dik[T], key: string, val: T or Option[T]) =
  runnableExamples("--gc:arc --experimental:strictFuncs --import:std/options"):
    var dict: Dik[string] = {"key": "value"}.toDik
    dict.add "other", "value"
    doAssert "other" in dict
    dict.add "another", some "value"
    doAssert "another" in dict
    dict.add "duplicated", "0"
    dict.add "duplicated", "1"
    dict.add "duplicated", "2"
    doAssert $dict == """{"key":value,"other":value,"another":value,"duplicated":2}"""
  assert key.len > 0, "key must not be empty string"
  assert key.len <= 32, "key must not be longer than 32 char"
  if self.items.len == self.cap.int:
    if self.allocated > 0: self.resized(self.len + self.len) else: self.resized(32)
  let hashish = hash(key)
  let (i1, i2) = self.lookup(key, hashish)
  let value = when val is T: some(val) else: val
  case i2
  of -1:
    self.items.add(Item[T](hash: hashish.uint32, key: arrai(key), val: value))
    self.indices[i1] = self.items.high
    inc self.len
  of -2: doAssert false, "ERROR: Failed to add a new item"
  else: self.items[i2].val = value

func get*[T](self: Dik[T], key: string): Option[T] =
  runnableExamples("--gc:arc --experimental:strictFuncs --import:std/options"):
    var dict: Dik[string] = {"key": "X"}.toDik
    doAssert dict.get"key" is Option[string] and dict.get"key".isSome and dict.get"key".get == "X"
  assert key.len > 0, "key must not be empty"
  if self.allocated < 1: raise newException(KeyError, "ERROR: Key not found or dictionary is empty")
  let (_, i) = self.lookup(key, hash(key))
  if i == -1: raise newException(KeyError, "ERROR: Key not found")
  result = self.items[i].val

func toSeq*[T](self: Dik[T]): seq[Option[T]] =
  runnableExamples("--gc:arc --experimental:strictFuncs --import:std/options"): doAssert {"a": 0, "b": 1, "c": 2}.toDik.toSeq is seq[Option[int]]
  result = newSeqOfCap[Option[T]](self.items.len)
  for item in self.items: result.add item.val

template `[]=`*[T](self: var Dik[T], key: string, val: T or Option[T]) = self.add(key, val)
  ## Alias for `Dik.add`.

template `[]`*[T](self: Dik[T], key: string): Option[T] = self.get(key)
  ## Alias for `Dik.get`.

template `[]`*[T](self: Dik[T], index: SomeInteger or BackwardsIndex): Option[T] =
  ## Get items by index or backwards index, **you can use the dictionary as if it was an array**.
  runnableExamples("--gc:arc --experimental:strictFuncs --import:std/options"):
    let dict = {"a": 0, "b": 1, "c": 2}.toDik
    doAssert dict[1] == some 1
    doAssert dict[^1] == some 2
    doAssert dict[uint8(2.0)] == some 2
  assert index.int >= 0, "index must be a natural positive integer"
  assert index.int <= self.len.int, "index must not be greater than len, index out of range"
  self.items[when index is SomeInteger: index.int else: index].val

proc `[]`*[T](self: Dik[T], slice: Slice[int]): seq[Option[T]] {.noinit.} =
  runnableExamples("--gc:arc --experimental:strictFuncs --import:std/options"):
    let dict = {"a": 0, "b": 1, "c": 2, "d": 3}.toDik
    doAssert dict[1..2] == @[some(1), some(2)]
  assert slice.a >= 0, "Slice A must be a natural positive integer"
  assert slice.b <= self.len.int, "Slice B must not be greater than len, index out of range"
  result = newSeqOfCap[Option[T]](slice.b - slice.a)
  for item in self.items[slice]: result.add item.val

func get*[T](self: Dik[T], value: Option[T]): seq[string] =
  ## Get keys by value, like a backwards `get` without reversing the dictionary.
  runnableExamples("--gc:arc --experimental:strictFuncs --import:std/options"): doAssert {"a": 0, "b": 1, "c": 0}.toDik.get(some 0) == @["a", "c"]
  for item in self.items:
    if item.val == value: result.add item.key.str

template len*(self: Dik): int = self.len.int

template cap*(self: Dik): int = self.cap.int

template `[]`*(s: Indices, i: int): int =
  ## .. warning:: **DO NOT USE.**
  var x: int
  if self.allocated.int64 <= 0xff:         x = cast[ptr UncheckedArray[int8]](s)[i]
  elif self.allocated.int64 <= 0xffff:     x = cast[ptr UncheckedArray[int16]](s)[i]
  elif self.allocated.int64 <= 0xffffffff: x = cast[ptr UncheckedArray[int32]](s)[i]
  else: doAssert false, "ERROR: Allocated size error"
  x

template `[]=`*(s: Indices, i: int, val: int) =
  ## .. warning:: **DO NOT USE.**
  if self.allocated.int64 <= 0xff:         cast[ptr UncheckedArray[int8]](s)[i]  = int8(val)
  elif self.allocated.int64 <= 0xffff:     cast[ptr UncheckedArray[int16]](s)[i] = int16(val)
  elif self.allocated.int64 <= 0xffffffff: cast[ptr UncheckedArray[int32]](s)[i] = int32(val)
  else: doAssert false, "ERROR: Allocated size error"

runnableExamples("--gc:arc --experimental:strictFuncs --import:std/tables"):
  doAssert sizeof(newDik[string]()) == sizeof(initOrderedTable[string, string]())
