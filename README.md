# Dik

Table implemented as optimized sorted hashed dictionary,
same size and API as a Table, 0 dependencies, ~300 lines.

Get items by index or `BackwardsIndex` or `Slice` or `string` key,
destructor, resize in-place, `toSeq`, `pretty`.

Documentation, Tests, Examples: https://juancarlospaco.github.io/dik

![](https://img.shields.io/github/languages/top/juancarlospaco/dik?style=for-the-badge)
![](https://img.shields.io/github/languages/count/juancarlospaco/dik?logoColor=green&style=for-the-badge)
![](https://img.shields.io/github/stars/juancarlospaco/dik?style=for-the-badge "Star faster-than-csv on GitHub!")
![](https://img.shields.io/maintenance/yes/2021?style=for-the-badge)
![](https://img.shields.io/github/languages/code-size/juancarlospaco/dik?style=for-the-badge)
![](https://img.shields.io/github/issues-raw/juancarlospaco/dik?style=for-the-badge "Bugs")
![](https://img.shields.io/github/issues-pr-raw/juancarlospaco/dik?style=for-the-badge "PRs")
![](https://img.shields.io/github/last-commit/juancarlospaco/dik?style=for-the-badge "Commits")
![](https://github.com/juancarlospaco/dik/actions/workflows/build.yml/badge.svg?branch=nim)


# Benchmark

| Operation | `Table`          | `Dik`               |
|-----------|------------------|---------------------|
| `del()`   | 974 microseconds | 301 microseconds    |
| `clear()` | 5 milliseconds   | 150 microseconds    |
| `add()`   | 418 microseconds | 250 microseconds    |
| `get()`   | 242 microseconds | 220 microseconds    |

[source](benchmark.nim)


# FAQ

- Whats the name ?.

[Dik](https://en.wikipedia.org/wiki/Dik-dik) is a Dict.


# Stars

![](https://starchart.cc/juancarlospaco/dik.svg)
