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
    dram_bandwidth=(
        ("dram__bytes.sum.peak_sustained", 1), ("dram__cycles_elapsed.avg.per_second", 1)
    ),
)

"""
    compute_flops(table)

Compute per-category and total FLOPS from an Nsight Compute metrics table.

# Arguments
- `table`: a `Tables.jl`-compatible table (rows or columnar) containing Nsight
  metric columns.

# Returns
A `NamedTuple` containing per-row vectors with the following fields:
- `FLOPS_fp64`
- `FLOPS_fp32`
- `FLOPS_fp16`
- `FLOPS_tensor_core`
- `FLOPS_total`
"""
function compute_flops(table)
    @assert istable(table)
    n = _nrows(table)
    function _sum_group(group_name)
        s = zeros(n)
        if group_name in keys(METRIC_FACTORS)
            group = getfield(METRIC_FACTORS, group_name)
        else
            throw(ArgumentError("Unknown metric group: $group_name"))
        end
        for (name, factor) in group
            s .+= _load_metric(table, (name, factor))
        end
        return s
    end
    frequency_hz = _load_metric(table, METRIC_FACTORS.frequency)  # Frequency (Hz)
    # Calculate FLOPS per category (sum of metrics * frequency)
    FLOPS_fp64 = _sum_group(:fp64) .* frequency_hz
    FLOPS_fp32 = _sum_group(:fp32) .* frequency_hz
    FLOPS_fp16 = _sum_group(:fp16) .* frequency_hz
    FLOPS_tensor_core = _sum_group(:tensor_core) .* frequency_hz
    # Total FLOPS
    FLOPS_total = FLOPS_fp64 .+ FLOPS_fp32 .+ FLOPS_fp16 .+ FLOPS_tensor_core
    return (;
        FLOPS_fp64=FLOPS_fp64,
        FLOPS_fp32=FLOPS_fp32,
        FLOPS_fp16=FLOPS_fp16,
        FLOPS_tensor_core=FLOPS_tensor_core,
        FLOPS_total=FLOPS_total,
    )
end

"""
    compute_peak_flops(table)

Compute per-precision theoretical peak FLOP/s and the FP32 FMA-derived peak.

# Arguments
- `table`: a `Tables.jl`-compatible table containing Nsight Compute metrics.

# Returns
A `NamedTuple` with fields:
- `peak_FLOPS_fp32::Vector{Float64}`: per-row FP32 FMA-derived and single-precision peak FLOP/s.
- `peak_FLOPS_fp64::Vector{Float64}`: per-row double-precision peak FLOP/s.
- `peak_FLOPS_fp16::Vector{Float64}`: per-row half-precision peak FLOP/s.
- `peak_FLOPS_tensor_core::Vector{Float64}`: per-row tensor-core peak FLOP/s.
- `peak_FLOPS_total::Vector{Float64}`: per-row total theoretical peak FLOP/s (sum of per-precision peaks).
"""
function compute_peak_flops(table)
    @assert istable(table)
    n = _nrows(table)
    frequency_hz = _load_metric(table, PEAK_METRIC_FACTORS.frequency)
    function _sum_group(group_name)
        s = zeros(n)
        if group_name in keys(PEAK_METRIC_FACTORS)
            group = getfield(PEAK_METRIC_FACTORS, group_name)
        else
            throw(ArgumentError("Unknown peak metric group: $group_name"))
        end
        for (name, factor) in group
            s .+= _load_metric(table, (name, factor))
        end
        return s
    end
    # Per-precision theoretical peaks (per-cycle counts times frequency)
    peak_FLOPS_fp64 = _sum_group(:fp64) .* frequency_hz
    peak_FLOPS_fp32 = _sum_group(:fp32) .* frequency_hz
    peak_FLOPS_fp16 = _sum_group(:fp16) .* frequency_hz
    peak_FLOPS_tensor_core = _sum_group(:tensor_core) .* frequency_hz
    # Total theoretical peak (sum of per-precision peaks)
    peak_FLOPS_total =
        peak_FLOPS_fp64 .+ peak_FLOPS_fp32 .+ peak_FLOPS_fp16 .+ peak_FLOPS_tensor_core
    return (;
        peak_FLOPS_fp64=peak_FLOPS_fp64,
        peak_FLOPS_fp32=peak_FLOPS_fp32,
        peak_FLOPS_fp16=peak_FLOPS_fp16,
        peak_FLOPS_tensor_core=peak_FLOPS_tensor_core,
        peak_FLOPS_total=peak_FLOPS_total,
    )
end

_nrows(table) = length(rows(table))  # Number of rows

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
