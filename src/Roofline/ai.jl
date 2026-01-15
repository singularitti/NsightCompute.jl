export compute_ai

"""
    compute_ai(table)

Compute per-category arithmetic intensity (AI = FLOPs / Bytes) using the
FLOPS computed by `compute_flops` and the DRAM bandwidth metric
`dram__bytes.sum.per_second`.

# Returns
A `NamedTuple` containing per-row vectors with the following fields:
- `AI_double_precision`
- `AI_single_precision`
- `AI_half_precision`
- `AI_tensor_core`
- `AI_total`
- `DRAM_bandwidth` (Bytes / second)

# Examples
```jldoctest
julia> table = (
...     "smsp__cycles_elapsed.avg.per_second" => [1.0],
...     "smsp__sass_thread_inst_executed_op_fadd_pred_on.sum.per_cycle_elapsed" => [1.0],
...     "dram__bytes.sum.per_second" => [2.0]
... )

julia> res = compute_ai(table)
julia> res.AI_total[1] ≈ compute_flops(table).FLOPS_total[1] / 2.0
true
```
"""
function compute_ai(table)
    @assert istable(table)
    # Get FLOPS vectors per category
    flops = compute_flops(table)
    DRAM_bandwidth = _load_metric(table, ("dram__bytes.sum.per_second", 10^12))
    AI_double_precision = _safe_div(flops.FLOPS_double_precision, DRAM_bandwidth)
    AI_single_precision = _safe_div(flops.FLOPS_single_precision, DRAM_bandwidth)
    AI_half_precision = _safe_div(flops.FLOPS_half_precision, DRAM_bandwidth)
    AI_tensor_core = _safe_div(flops.FLOPS_tensor_core, DRAM_bandwidth)
    # Compute AI_total per-row as the maximum across categories using
    # `maximum` on each zipped tuple of category AIs.
    AI_total = maximum.(zip(AI_double_precision, AI_single_precision, AI_half_precision))
    return (;
        AI_double_precision=AI_double_precision,
        AI_single_precision=AI_single_precision,
        AI_half_precision=AI_half_precision,
        AI_total=AI_total,
    )
end

function _safe_div(num, denom)
    if size(denom) != size(num)
        throw(DimensionMismatch("sizes do not match!"))
    end
    # `num` and `denom` are vectors. `denom` may contain zeros.
    # Make every element zero by default, and only perform division where `denom` is non-zero.
    out = zeros(eltype(typeof(oneunit(eltype(num)) / oneunit(eltype(denom)))), length(num))
    for i in eachindex(num)
        if !iszero(denom[i])  # Only divide when `denom` is non-zero
            out[i] = num[i] / denom[i]
        end
    end
    return out
end
