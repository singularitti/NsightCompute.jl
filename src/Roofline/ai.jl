export compute_dram_bandwidth, compute_ai

"""
    compute_dram_bandwidth(table, peak=false)

Return the DRAM bandwidth in TB/s.
"""
function compute_dram_bandwidth(table, peak=false)
    @assert istable(table)
    if peak
        peak_bytes_per_cycle = _load_metric(table, ("dram__bytes.sum.peak_sustained", 10^3)) # kB/cycle (decimal)
        cycles_per_second = _load_metric(table, ("dram__cycles_elapsed.avg.per_second", 10^9)) # cycles/s
        bytes_per_second = peak_bytes_per_cycle .* cycles_per_second
        tb_per_second = bytes_per_second ./ 10^12
        return tb_per_second
    else
        # Measured metric is reported in TB/s; return it directly.
        return _load_metric(table, ("dram__bytes.sum.per_second", 0.0))
    end
end

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
