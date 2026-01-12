---
description: "Standards for writing Julia docstrings."
applyTo: '**/*.jl'
---

# Julia Docstrings Standards

Use these rules when generating or reviewing docstrings.

## Actionable Checklist (Follow In Order)

1. Signature block
   - Start the docstring with a four-space indented signature block showing common calling forms and default values (e.g., `f(x, y=1)`). Use `f(x[, y])` for optional args without defaults. For many keyword args, use `f(x; <keyword arguments>)`.
   - Indicate return type or named returns when relevant: `::Type` or `-> name::Type`.

2. One-line summary
   - Immediately after the signature write a single-line summary in the imperative mood ending with a period. Keep it short (≤120 characters if possible).
   - Add one blank line before any extended description.

3. Do not repeat the signature: Do not repeat information already present in the signature (types or obvious parameter names).

4. Arguments section (`# Arguments`)
   - Add `# Arguments` only for complex functions or many arguments.
   - Use one `-` bullet per argument and include type/default when helpful:
     - `n::Integer=1`: number of elements.

5. See also: When useful, add a `See also` paragraph listing related functions, e.g., "See also [`bar!`](@ref), [`baz`](@ref)."

6. Examples and doctests (`# Examples`)
   - Put runnable examples under `# Examples` and use fenced `jldoctest` blocks for doctests.
   - Examples must be self-contained, deterministic, and platform-independent where possible. Avoid unseeded `rand`; seed a local RNG if needed (e.g., `rng = MersenneTwister(123)`).
   - Use `[...]` to truncate or hide non-deterministic parts (e.g., stack traces).
   - Verify examples with the project's doctest command (e.g., `make -C doc doctest=true`).

7. Formatting: code, quoting, and lines
   - Use backticks for identifiers and small code fragments: `foo`.
   - Prefer Unicode for math examples (e.g., ``α = 1``) over LaTeX escapes.
   - Put the opening and closing `"""` on their own lines for multi-line docstrings.
   - Keep lines ≤ 92 characters when practical.

8. Returns and yields: Use `# Returns` to describe return values. For generators, use `# Yields`.

9. Methods and generic functions: Prefer documenting the generic function once. Document specific methods only if their behavior differs or the method is important on its own.

10. Implementation and developer notes: Use `# Implementation` to describe which methods should be implemented or overridden (developer-facing information).

11. Long docs and extended help: Split very long docstrings with an `# Extended help` header so default help remains concise.

## Other Rules And Advanced Usage

- Docstring placement: Do not insert a blank line between a docstring and the object it documents.
- Use `@doc` to attach programmatic Markdown. Use `raw"""..."""` to avoid escaping `$` and `\` when needed.
- For instance-dependent documentation consider `Docs.getdoc(::YourType)`.
- Modules and Types:
  - Module docstrings should state purpose and key exports.
  - Type docstrings should explain what an instance represents and may include an `Attributes:` section for public fields.
  - Field docstrings belong immediately before the field inside the `struct`.
  - Inner constructors can be documented with `@doc` or a docstring placed immediately above the constructor.
- Doctest robustness: avoid global RNGs and platform-dependent outputs (word-size or path separators).
- Changelog: Record breaking changes clearly (e.g., a `BREAKING CHANGE` note).
- Formatting rule: If a main point has exactly one nested sub-bullet, append that single sub-bullet inline after the main point following a colon (example: "3. Do not repeat the signature: ...").

## Minimal Examples (Follow Exact Structure)

````julia
"""
    foo(x, y=1)

Short imperative summary.

More detailed explanation if needed.

# Arguments
- `x::Integer`: the number of elements to compute.
- `y::Integer=1`: the dimensions along which to perform the computation.

# Examples
```jldoctest
julia> foo(1)
2
```
"""
function foo(x, y=1)
    x + y
end

"""
    empty(v::AbstractVector, [eltype])

Create an empty vector similar to `v`, optionally changing the `eltype`.

See also: [`empty!`](@ref), [`isempty`](@ref), [`isassigned`](@ref).

# Examples

```jldoctest
julia> empty([1.0, 2.0, 3.0])
Float64[]

julia> empty([1.0, 2.0, 3.0], String)
String[]
```
"""
empty
````

## Quick Reviewer Checklist

- Signature is shown and indented with four spaces.
- One-line imperative summary is present and concise.
- The prose does not repeat signature details (types, obvious names).
- `# Arguments` exists only when necessary and uses one `-` bullet per argument.
- `# Examples` contains deterministic `jldoctest` blocks.
- `"""` appear on their own lines and the docstring immediately precedes the object.
- Lines respect the 92-character guideline where practical and identifiers use backticks.
- Add `# Implementation` or `# Extended help` for developer-facing details when appropriate.

When generating or editing docstrings, follow this checklist exactly and avoid emojis or informal decorations.
