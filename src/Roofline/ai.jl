export compute_ai

"""
    compute_ai(table)

Compute per-category arithmetic intensity (AI = FLOPs / Bytes).
"""
function compute_ai(table)
    @assert istable(table)
    # Get FLOPS vectors per category
    flops = compute_flops(table)
    DRAM_bandwidth = _load_metric(table, ("dram__bytes.sum.per_second", 10^12))  # Bandwidth in TB/s
    AI_fp64 = _safe_div(flops.FLOPS_fp64, DRAM_bandwidth)
    AI_fp32 = _safe_div(flops.FLOPS_fp32, DRAM_bandwidth)
    AI_fp16 = _safe_div(flops.FLOPS_fp16, DRAM_bandwidth)
    # Compute AI_total per-row as the maximum across categories
    AI_total = maximum.(zip(AI_fp64, AI_fp32, AI_fp16))
    return (; AI_fp64=AI_fp64, AI_fp32=AI_fp32, AI_fp16=AI_fp16, AI_total=AI_total)
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
