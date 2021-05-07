import std/[tables, times]
import dik

const sizeForBench = 999

template tableBench(name: string; code) =
  block:
    var tabla {.inject.} = initTable[string, bool](sizeForBench)
    for i in 0 .. sizeForBench: tabla.add $i, false
    let t = now()
    code
    echo "TABLE\t", name, "()\t", now() - t

template dikBench(name: string; code) =
  block:
    var dict {.inject.} = newDikOfCap[bool](sizeForBench)
    for i in 0 .. sizeForBench: dict.add $i, false
    let t = now()
    code
    echo "DIK\t", name, "()\t", now() - t

template line() = echo "------------------------------------------------------------------------------"

proc main() =
  tableBench "del":
    for i in 0 .. sizeForBench:
      tabla.del $i

  dikBench "del":
    for i in 0 .. sizeForBench:
      dict.del $i

  line()

  tableBench "clear":
    for i in 0 .. sizeForBench:
      tabla.clear()

  dikBench "clear":
    for i in 0 .. sizeForBench:
      dict.clear()

  line()

  tableBench "add":
    for i in 0 .. sizeForBench:
      tabla.add $i, false

  dikBench "add":
    for i in 0 .. sizeForBench:
      dict.add $i, false

  line()

  tableBench "get":
    for i in 0 .. sizeForBench:
      discard tabla[$i]

  dikBench "get":
    for i in 0 .. sizeForBench:
      discard dict[$i]


when isMainModule:
  main()
