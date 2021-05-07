import std/[tables, times]
import dik

const sizeForBench = 999  # Tested values `999` and `999_999`.

template tableBench(name: string; code) =
  block:
    var tabla {.inject.} = initTable[string, bool](sizeForBench)
    for i in 0 .. sizeForBench: tabla.add $i, false
    let t = now()
    code
    result.add "  | `" & name & "()`   | " & $(now() - t)

template dikBench(code) =
  block:
    var dict {.inject.} = newDikOfCap[bool](sizeForBench)
    for i in 0 .. sizeForBench: dict.add $i, false
    let t = now()
    code
    result.add " | " & $(now() - t) & " |\n"

proc main(): string =
  result = """
  | Operation | `Table`          | `Dik`               |
  |-----------|------------------|---------------------|
"""

  tableBench "del":
    for i in 0 .. sizeForBench:
      tabla.del $i

  dikBench:
    for i in 0 .. sizeForBench:
      dict.del $i


  tableBench "clear":
    for i in 0 .. sizeForBench:
      tabla.clear()

  dikBench:
    for i in 0 .. sizeForBench:
      dict.clear()


  tableBench "add":
    for i in 0 .. sizeForBench:
      tabla.add $i, false

  dikBench:
    for i in 0 .. sizeForBench:
      dict.add $i, false


  tableBench "get":
    for i in 0 .. sizeForBench:
      discard tabla[$i]

  dikBench:
    for i in 0 .. sizeForBench:
      discard dict[$i]


when isMainModule:
  echo main()
