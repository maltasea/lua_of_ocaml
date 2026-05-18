# Project Scan Report

Date: 2026-05-18
Repository: `lua_of_ocaml`
Scope: repository inventory, static code review, build/test verification, and generated Lua smoke checks.

## Executive Summary

`lua_of_ocaml` is a compact OCaml bytecode to Lua 5.1 compiler. It reuses `js_of_ocaml-compiler` for bytecode parsing and IR, then lowers that IR to a local Lua AST, pretty-prints Lua, and prepends a split Lua runtime from `runtime/lua`.

The project builds and its current shell test suite passes when run under the matching opam switch. The default shell environment is inconsistent, however: `ocamlc` resolves to OCaml 5.4.1 from `/usr/local/bin`, while opam packages are installed for switch `5.3.0+BER`. Plain `dune build` fails in that environment.

The main product risk is that the compiler tests mostly prove Lua syntax generation, not executable correctness. A generated Lua program from `test/minimal.ml` currently fails at runtime on missing primitives (`caml_atomic_load` and `caml_atomic_cas`), even though `test/run_tests.sh` reports 26/26 passing under the correct switch. The generated output also contains two `_main()` calls, which would duplicate side effects once runtime execution gets past the missing primitive.

## Repository Inventory

Main tracked areas:

- `compiler/lib/lua.ml` and `compiler/lib/lua.mli`: Lua 5.1 AST and constructors.
- `compiler/lib/lua_output.ml`: Lua pretty-printer.
- `compiler/lib/generate_lua.ml`: `js_of_ocaml` IR to Lua AST generator.
- `compiler/bin-lua_of_ocaml/main.ml`: CLI entry point and runtime loader.
- `runtime/lua/*.lua`: split Lua runtime files.
- `test/run_tests.sh`: shell test runner with compiler smoke tests, source tracing checks, and runtime unit checks.

Current handwritten/project LOC, excluding generated `.lua` and `.byte` artifacts: about 1,872 lines.

Tracked generated artifacts are present:

- `hello.byte`
- `hello.lua`
- `test/hello.byte`
- `test/hello.lua`

Final git status after writing this report shows only `PROJECT_SCAN_REPORT.md` as an untracked file.

## Build And Test Results

Commands run:

- `dune build`
  - Result: failed in the default shell.
  - Cause: `js_of_ocaml-compiler.cmi` in `/Users/ben/.opam/5.3.0+BER` was compiled for an older/different OCaml than the active `/usr/local/bin/ocamlc` 5.4.1.

- `opam exec --switch=5.3.0+BER -- dune build`
  - Result: passed.

- `test/run_tests.sh`
  - Result: failed in the default shell for the same compiler/interface mismatch.

- `opam exec --switch=5.3.0+BER -- test/run_tests.sh`
  - Result: passed, 26 passed / 0 failed.

- `opam exec --switch=5.3.0+BER -- dune runtest`
  - Result: passed but did not run the shell suite; there is no Dune test alias/stanza wired to `test/run_tests.sh`.

- Generated runtime smoke check from `test/minimal.ml`
  - Compile and generate succeeded.
  - `lua /tmp/loo_scan_minimal.lua` failed with: `attempt to call global 'caml_atomic_load' (a nil value)`.

Toolchain observed:

- `opam switch show`: `5.3.0+BER`
- opam `ocaml`: `5.3.0`
- `js_of_ocaml-compiler`: `6.2.0`
- `dune`: `3.20.2`
- default `ocamlc`: `/usr/local/bin/ocamlc`, version `5.4.1`
- `lua`: Lua 5.1.5

## Findings

### High: Generated Lua does not execute simple programs

The generated Lua for `test/minimal.ml` references `caml_atomic_load` and `caml_atomic_cas`, but the runtime only defines field-oriented atomic helpers such as `caml_atomic_load_field` and `caml_atomic_cas_field` in `runtime/lua/misc.lua`.

Evidence from generated output:

- `caml_atomic_load(exit_function_759)`
- `caml_atomic_cas(f_yet_to_run_763, ...)`

Runtime evidence:

- `runtime/lua/misc.lua` defines `caml_atomic_load_field`, `caml_atomic_cas_field`, `caml_atomic_exchange_field`, `caml_atomic_store_field`, and `caml_atomic_set_field`.
- It does not define `caml_atomic_load` or `caml_atomic_cas`.

Impact: programs using the normal OCaml runtime initialization path can generate syntactically valid Lua that fails immediately at runtime.

### High: `_main()` is emitted twice

There are two entry calls:

- `compiler/lib/generate_lua.ml` returns an `_main` function assignment and an immediate `_main()` expression statement.
- `compiler/bin-lua_of_ocaml/main.ml` appends another `_main()` after printing the Lua program.

Generated evidence from `/tmp/loo_scan_minimal.lua`:

```lua
_main()
_main()
```

Impact: once runtime execution reaches the program body, side effects can happen twice.

### High: Test suite passes while generated programs fail at runtime

The compiler smoke tests in `test/run_tests.sh` compile OCaml inputs, run the compiler, and check Lua syntax with `loadfile`. They do not run the generated Lua for behavioral assertions. The helper `check_lua_runs` exists but is not used in the compiler smoke section.

Impact: missing runtime primitives, duplicate `_main()` calls, wrong output, and many semantic regressions can pass CI if CI only invokes this script.

### Medium: Package metadata is incorrect and incomplete

`lua_of_ocaml.opam` currently says:

- synopsis: `Lua to OCaml compiler`
- description: `A compiler from Lua to OCaml.`

That is the opposite of the README and implementation. The opam file also lists only `dune` and optional `odoc`, while the build requires `js_of_ocaml-compiler`.

Because the opam file says it is generated by Dune, this should be fixed in `dune-project` package metadata and regenerated.

### Medium: Runtime loading is tied to repository working directory

`compiler/bin-lua_of_ocaml/main.ml` loads runtime files from the relative path `runtime/lua`. If the compiler is run from another directory or installed as a binary, it will warn about missing runtime files and still emit Lua.

Impact: installed or scripted use can produce incomplete Lua without a hard failure.

### Medium: Dune test integration is missing

`opam` builds with `@runtest` under `{with-test}`, and `dune runtest` exits successfully, but it does not invoke `test/run_tests.sh`.

Impact: package/test automation can report success without running the actual test suite.

### Medium: Generated artifacts and ignore rules need cleanup

`.gitignore` contains `.byte` and `.lua`, which only match files literally named `.byte` or `.lua`. It likely intended `*.byte` and `*.lua`.

Generated artifacts are currently tracked in the repository (`hello.lua`, `hello.byte`, `test/hello.lua`, `test/hello.byte`). If these are examples/golden files, they should be named and documented as such. If they are build output, they should be untracked and ignored.

### Low: Documentation is stale after runtime split/deletion

The README architecture and file list still describe `compiler/lib/runtime_lua.ml` as the embedded runtime source. That file is not present in the current tracked file list, and the CLI loads `runtime/lua/*.lua` directly.

### Low: CLI argument handling is permissive

Unknown flags are silently skipped. A missing runtime file only prints a warning and continues. For a compiler CLI, explicit failure modes would be easier to diagnose and safer for automation.

## Strengths

- The core architecture is cleanly separated into AST, printer, generator, CLI, runtime, and tests.
- Reusing `js_of_ocaml-compiler` IR is a pragmatic choice and keeps bytecode parsing out of scope.
- The split runtime files are easier to inspect and unit-test than a single embedded string blob.
- Source tracing support is present and covered by the shell suite.
- The existing tests provide useful coverage for syntax generation and individual runtime functions.

## Recommended Next Steps

1. Fix executable correctness first:
   - Add `caml_atomic_load` and `caml_atomic_cas`, or translate those primitives to the existing field-based runtime helpers if that is semantically correct.
   - Remove one of the two `_main()` emissions.

2. Strengthen tests:
   - Run generated Lua for `minimal`, `hello`, arithmetic, functions, closures, lists, and exceptions.
   - Assert stdout/stderr and exit status, not only Lua syntax.
   - Add a regression test that generated output contains exactly one `_main()` call.

3. Normalize the developer environment:
   - Use `opam exec --switch=5.3.0+BER -- ...`, or load `eval $(opam env --switch=5.3.0+BER)` before building.
   - Avoid mixing `/usr/local/bin/ocamlc` 5.4.1 with opam packages from the 5.3.0 switch.

4. Fix package and test metadata:
   - Add package metadata to `dune-project`.
   - Correct the synopsis/description.
   - Declare `js_of_ocaml-compiler`.
   - Wire `test/run_tests.sh` into Dune's runtest alias.

5. Decide how runtime files are packaged:
   - Embed runtime files at build time, install them and locate them relative to the executable, or require an explicit runtime path.
   - Treat missing runtime files as a hard error.

6. Clean repository hygiene:
   - Correct `.gitignore` to ignore generated `*.byte`, `*.lua`, `*.cmi`, and `*.cmo` as intended.
   - Remove generated artifacts from git unless they are deliberate examples/golden outputs.
   - Update README references to the runtime layout.

## Overall Assessment

The project is a promising early-stage compiler prototype with an understandable structure and a useful smoke-test scaffold. It is not yet reliable as an executable compiler because the current tests do not prove generated-program behavior, and a trivial generated program fails at runtime. The fastest path to a materially stronger project is to close the primitive/runtime gaps, remove the duplicate entry call, and convert the smoke tests from syntax checks into actual run-and-assert tests.
