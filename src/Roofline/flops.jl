using Tables: Tables, columnnames, istable

export compute_flops

const METRIC_FACTORS = (
    frequency=("smsp__cycles_elapsed.avg.per_second", 10^9),
    double_precision=(
        ("smsp__sass_thread_inst_executed_op_dadd_pred_on.sum.per_cycle_elapsed", 1),
        ("smsp__sass_thread_inst_executed_op_dmul_pred_on.sum.per_cycle_elapsed", 1),
        ("smsp__sass_thread_inst_executed_op_dfma_pred_on.sum.per_cycle_elapsed", 2),
    ),
    single_precision=(
        ("smsp__sass_thread_inst_executed_op_fadd_pred_on.sum.per_cycle_elapsed", 1),
        ("smsp__sass_thread_inst_executed_op_fmul_pred_on.sum.per_cycle_elapsed", 1),
        ("smsp__sass_thread_inst_executed_op_ffma_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_fadd2_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_fmul2_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_ffma2_pred_on.sum.per_cycle_elapsed", 4),
    ),
    half_precision=(
        ("smsp__sass_thread_inst_executed_op_hadd_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_hmul_pred_on.sum.per_cycle_elapsed", 2),
        ("smsp__sass_thread_inst_executed_op_hfma_pred_on.sum.per_cycle_elapsed", 4),
    ),
    tensor_core=(
        ("sm__ops_path_tensor_src_fp64.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_tf32_dst_fp32.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_bf16_dst_fp32.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp16.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_int1.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_int4.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_int8.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp8_sparsity_off.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp8_sparsity_on.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_dst_fp32.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_dst_fp16.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_dst_fp32.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_fp8_dst_fp16.sum.per_cycle_elapsed", 1),
        ("sm__ops_path_tensor_src_fp4_fp6_fp8_dst_fp32.sum.per_cycle_elapsed", 1),
    ),
)

"""
    compute_flops(table)

Compute per-category and total FLOPS from an Nsight Compute metrics table.

# Arguments
- `table`: a Tables-compatible table (rows or columnar) containing Nsight
  metric columns.

# Returns
A `NamedTuple` containing per-row vectors with the following fields:
- `FLOPS_double_precision`
- `FLOPS_single_precision`
- `FLOPS_half_precision`
- `FLOPS_tensor_core`
- `FLOPS_total`
"""
function compute_flops(table)
    @assert istable(table)
    n = length(Tables.rows(table))
    _load_metric((name, factor)) =
        (name in columnnames(table)) ? safe_column(table[:, name]) .* factor : zeros(n)
    function _sum_group(group::Symbol)
        s = zeros(n)
        grp = getfield(METRIC_FACTORS, group)
        for (name, factor) in grp
            s .+= _load_metric((name, factor))
        end
        return s
    end
    frequency_hz = _load_metric(METRIC_FACTORS.frequency)  # Frequency in Hz
    # Compute FLOPS per category by summing metrics in each group then multiplying by frequency
    FLOPS_double_precision = _sum_group(:double_precision) .* frequency_hz
    FLOPS_single_precision = _sum_group(:single_precision) .* frequency_hz
    FLOPS_half_precision = _sum_group(:half_precision) .* frequency_hz
    FLOPS_tensor_core = _sum_group(:tensor_core) .* frequency_hz
    # Final total (per-category FLOPS are computed above)
    FLOPS_total =
        FLOPS_double_precision .+ FLOPS_single_precision .+ FLOPS_half_precision .+
        FLOPS_tensor_core
    return (;
        FLOPS_double_precision=FLOPS_double_precision,
        FLOPS_single_precision=FLOPS_single_precision,
        FLOPS_half_precision=FLOPS_half_precision,
        FLOPS_tensor_core=FLOPS_tensor_core,
        FLOPS_total=FLOPS_total,
    )
end

function safe_column(col)
    if eltype(col) <: AbstractString
        return [v == "no data" ? 0.0 : parse(Float64, v) for v in col]
    else
        return coalesce.(col, 0.0)
    end
end
