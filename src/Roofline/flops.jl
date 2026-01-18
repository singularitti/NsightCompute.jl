using Tables: columnnames, getcolumn, istable, rows

export compute_flops, compute_peak_flops

const METRIC_FACTORS = (
    frequency=("smsp__cycles_elapsed.avg.per_second", 10^9),  # GHz
    fp64=(
        ("smsp__sass_thread_inst_executed_op_dadd_pred_on.sum.per_cycle_elapsed", 1),
        ("smsp__sass_thread_inst_executed_op_dmul_pred_on.sum.per_cycle_elapsed", 1),
        ("smsp__sass_thread_inst_executed_op_dfma_pred_on.sum.per_cycle_elapsed", 2),
    ),
    fp32=(
        ("smsp__sass_thread_inst_executed_op_fadd_pred_on.sum.per_cycle_elapsed", 1),
        ("smsp__sass_thread_inst_executed_op_fmul_pred_on.sum.per_cycle_elapsed", 1),
        ("smsp__sass_thread_inst_executed_op_ffma_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_fadd2_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_fmul2_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_ffma2_pred_on.sum.per_cycle_elapsed", 4),
    ),
    fp16=(
        ("smsp__sass_thread_inst_executed_op_hadd_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_hmul_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_hfma_pred_on.sum.per_cycle_elapsed", 4),
    ),
    tensor_core=(
        ("sm__ops_path_tensor_op_bgmma_src_int1.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_bmma_src_int1.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hgmma_src_bf16_dst_fp32_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hgmma_src_bf16_dst_fp32_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hgmma_src_fp16_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hgmma_src_fp16_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hgmma_src_tf32_dst_fp32_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hgmma_src_tf32_dst_fp32_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hmma_src_bf16_dst_fp32_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hmma_src_bf16_dst_fp32_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hmma_src_fp16_dst_fp16_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hmma_src_fp16_dst_fp16_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hmma_src_fp16_dst_fp32_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hmma_src_fp16_dst_fp32_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hmma_src_tf32_dst_fp32_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_hmma_src_tf32_dst_fp32_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_igmma_src_int8_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_igmma_src_int8_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_imma_src_int8_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_op_imma_src_int8_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_bf16_dst_fp32.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp16.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_dst_fp32.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_dst_fp16.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_dst_fp32.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_fp8_dst_fp16.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_fp8_dst_fp32.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp64.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp8_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp8_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_int1.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_int4.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_int8.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_tf32_dst_fp32.sum.per_cycle_elapsed", 1),
    ),
)

# Peak-related metric definitions for computing theoretical roofline boundaries.
const PEAK_METRIC_FACTORS = (
    frequency=("sm__cycles_elapsed.avg.per_second", 10^9),
    fp64=(("sm__sass_thread_inst_executed_op_dfma_pred_on.sum.peak_sustained", 2),),
    fp32=(("sm__sass_thread_inst_executed_op_ffma_pred_on.sum.peak_sustained", 2),),
    fp16=(("sm__sass_thread_inst_executed_op_hfma_pred_on.sum.peak_sustained", 4),),
    tensor_core=(
        ("sm__ops_path_tensor_op_bgmma_src_int1.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_bmma_src_int1.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hgmma_src_bf16_dst_fp32_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hgmma_src_bf16_dst_fp32_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hgmma_src_fp16_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hgmma_src_fp16_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hgmma_src_tf32_dst_fp32_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hgmma_src_tf32_dst_fp32_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hmma_src_bf16_dst_fp32_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hmma_src_bf16_dst_fp32_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hmma_src_fp16_dst_fp16_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hmma_src_fp16_dst_fp16_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hmma_src_fp16_dst_fp32_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hmma_src_fp16_dst_fp32_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hmma_src_tf32_dst_fp32_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_hmma_src_tf32_dst_fp32_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_igmma_src_int8_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_igmma_src_int8_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_imma_src_int8_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_op_imma_src_int8_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_bf16_dst_fp32.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp16.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp4_dst_fp32.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_dst_fp16.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_dst_fp32.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_fp8_dst_fp16.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_fp8_dst_fp32.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp64.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp8_sparsity_off.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_fp8_sparsity_on.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_int1.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_int4.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_int8.sum.peak_sustained", 1),
        ("sm__ops_path_tensor_src_tf32_dst_fp32.sum.peak_sustained", 1),
    ),
)

"""
    compute_flops(table, peak=false)

Compute per-category and total FLOP/s from an Nsight Compute metrics table.

When `peak=false` (default) this computes measured FLOP/s from running metrics.
When `peak=true` this computes theoretical peak FLOP/s from the peak metric
mapping (`PEAK_METRIC_FACTORS`).

# Arguments
- `table`: a `Tables.jl`-compatible table (rows or columnar) containing Nsight
  metric columns.
- `peak::Bool=false`: whether to compute theoretical peak FLOP/s.

# Returns
A `NamedTuple` containing per-row vectors. When `peak=false` the fields are:
- `FLOPS_fp64`
- `FLOPS_fp32`
- `FLOPS_fp16`
- `FLOPS_tensor_core`
- `FLOPS_total`

When `peak=true` the fields are:
- `peak_FLOPS_fp64`
- `peak_FLOPS_fp32`
- `peak_FLOPS_fp16`
- `peak_FLOPS_tensor_core`
- `peak_FLOPS_total`
"""
function compute_flops(table, peak=false)
    @assert istable(table)
    metrics = peak ? PEAK_METRIC_FACTORS : METRIC_FACTORS
    frequency_hz = _load_metric(table, metrics.frequency)  # Frequency (Hz)
    # Calculate FLOPS per category (sum of metrics * frequency)
    fp64 = _sum_metric_group(table, metrics, :fp64) .* frequency_hz
    fp32 = _sum_metric_group(table, metrics, :fp32) .* frequency_hz
    fp16 = _sum_metric_group(table, metrics, :fp16) .* frequency_hz
    tensor = _sum_metric_group(table, metrics, :tensor_core) .* frequency_hz
    total = fp64 .+ fp32 .+ fp16 .+ tensor
    if peak
        return (;
            peak_FLOPS_fp64=fp64,
            peak_FLOPS_fp32=fp32,
            peak_FLOPS_fp16=fp16,
            peak_FLOPS_tensor_core=tensor,
            peak_FLOPS_total=total,
        )
    else
        return (;
            FLOPS_fp64=fp64,
            FLOPS_fp32=fp32,
            FLOPS_fp16=fp16,
            FLOPS_tensor_core=tensor,
            FLOPS_total=total,
        )
    end
end

_nrows(table) = length(rows(table))  # Number of rows

# Sum a metric group from the provided metrics mapping (e.g., `METRIC_FACTORS`
# or `PEAK_METRIC_FACTORS`) for the given `table`.
function _sum_metric_group(table, metrics::NamedTuple, group_name::Symbol)
    n = _nrows(table)
    s = zeros(n)
    if group_name in keys(metrics)
        group = getfield(metrics, group_name)
    else
        throw(ArgumentError("Unknown metric group: $group_name"))
    end
    for (name, factor) in group
        s .+= _load_metric(table, (name, factor))
    end
    return s
end

# Index of the column matching the name
function _locatename(name, table)
    indices = findall(startswith(name), string.(columnnames(table)))
    if isempty(indices)  # Name not found
        return nothing
    end
    return only(indices)  # Errors if multiple matches found
end

# Load metric column and apply scaling factor
function _load_metric(table, (name, factor))
    index = _locatename(name, table)
    if isnothing(index)  # Column not found
        return zeros(_nrows(table))
    else
        return _safer_column(getcolumn(table, index)) .* factor
    end
end

# Convert to Float64, handling "no data" and missing values
function _safer_column(col)
    if eltype(col) <: AbstractString
        return [v == "no data" ? 0.0 : parse(Float64, v) for v in col]
    else
        return coalesce.(col, 0.0)
    end
end
