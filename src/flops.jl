using CSV: File
using DataFrames: hcat, nrow

export compute_flops

function compute_flops(data::DataFrame)
    # GPU frequency (Hz) from SM average frequency (GHz)
    gpu_freq_hz = data[:, "smsp__cycles_elapsed.avg.per_second"] .* 10^9
    # Instruction counts per cycle (inst/cycle)
    # Double precision
    inst_dadd = data[
        :, "smsp__sass_thread_inst_executed_op_dadd_pred_on.sum.per_cycle_elapsed"
    ]
    inst_dmul = data[
        :, "smsp__sass_thread_inst_executed_op_dmul_pred_on.sum.per_cycle_elapsed"
    ]
    inst_dfma =
        data[:, "smsp__sass_thread_inst_executed_op_dfma_pred_on.sum.per_cycle_elapsed"] .*
        2
    # Single precision
    inst_fadd = data[
        :, "smsp__sass_thread_inst_executed_op_fadd_pred_on.sum.per_cycle_elapsed"
    ]
    inst_fmul = data[
        :, "smsp__sass_thread_inst_executed_op_fmul_pred_on.sum.per_cycle_elapsed"
    ]
    inst_ffma =
        data[:, "smsp__sass_thread_inst_executed_op_ffma_pred_on.sum.per_cycle_elapsed"] .*
        2
    inst_fadd2 =
        safe_column(
            data[
                :, "smsp__sass_thread_inst_executed_op_fadd2_pred_on.sum.per_cycle_elapsed"
            ],
        ) .* 2
    inst_fmul2 =
        safe_column(
            data[
                :, "smsp__sass_thread_inst_executed_op_fmul2_pred_on.sum.per_cycle_elapsed"
            ],
        ) .* 2
    inst_ffma2 =
        safe_column(
            data[
                :, "smsp__sass_thread_inst_executed_op_ffma2_pred_on.sum.per_cycle_elapsed"
            ],
        ) .* 4
    # Half precision
    inst_hadd =
        safe_column(
            data[:, "smsp__sass_thread_inst_executed_op_hadd_pred_on.sum.per_cycle_elapsed"]
        ) .* 2
    inst_hmul =
        safe_column(
            data[:, "smsp__sass_thread_inst_executed_op_hmul_pred_on.sum.per_cycle_elapsed"]
        ) .* 2
    inst_hfma =
        safe_column(
            data[:, "smsp__sass_thread_inst_executed_op_hfma_pred_on.sum.per_cycle_elapsed"]
        ) .* 4
    # Tensor core (from raw tensor metrics)
    # Standard precisions
    tc_fp64 = safe_column(data[:, "sm__ops_path_tensor_src_fp64.sum.per_cycle_elapsed"])
    tc_tf32 = safe_column(
        data[:, "sm__ops_path_tensor_src_tf32_dst_fp32.sum.per_cycle_elapsed"]
    )
    tc_bf16 = safe_column(
        data[:, "sm__ops_path_tensor_src_bf16_dst_fp32.sum.per_cycle_elapsed"]
    )
    tc_fp16 = safe_column(data[:, "sm__ops_path_tensor_src_fp16.sum.per_cycle_elapsed"])  # Aggregate covering dst_fp16 & dst_fp32
    # Integer precisions
    tc_int1 = safe_column(data[:, "sm__ops_path_tensor_src_int1.sum.per_cycle_elapsed"])
    tc_int4 = safe_column(data[:, "sm__ops_path_tensor_src_int4.sum.per_cycle_elapsed"])
    tc_int8 = safe_column(data[:, "sm__ops_path_tensor_src_int8.sum.per_cycle_elapsed"])
    # FP8
    tc_fp8_off = safe_column(
        data[:, "sm__ops_path_tensor_src_fp8_sparsity_off.sum.per_cycle_elapsed"]
    )
    tc_fp8_on = safe_column(
        data[:, "sm__ops_path_tensor_src_fp8_sparsity_on.sum.per_cycle_elapsed"]
    )
    # FP4 & Mixed precision
    tc_fp4 = safe_column(
        data[:, "sm__ops_path_tensor_src_fp4_dst_fp32.sum.per_cycle_elapsed"]
    )
    tc_fp4_fp6_16 = safe_column(
        data[:, "sm__ops_path_tensor_src_fp4_fp6_dst_fp16.sum.per_cycle_elapsed"]
    )
    tc_fp4_fp6_32 = safe_column(
        data[:, "sm__ops_path_tensor_src_fp4_fp6_dst_fp32.sum.per_cycle_elapsed"]
    )
    tc_fp4_fp6_fp8_16 = safe_column(
        data[:, "sm__ops_path_tensor_src_fp4_fp6_fp8_dst_fp16.sum.per_cycle_elapsed"]
    )
    tc_fp4_fp6_fp8_32 = safe_column(
        data[:, "sm__ops_path_tensor_src_fp4_fp6_fp8_dst_fp32.sum.per_cycle_elapsed"]
    )
    # Summation
    FLOPS_double_precision = (inst_dadd .+ inst_dmul .+ inst_dfma) .* gpu_freq_hz
    FLOPS_single_precision =
        (inst_fadd .+ inst_fmul .+ inst_ffma .+ inst_fadd2 .+ inst_fmul2 .+ inst_ffma2) .*
        gpu_freq_hz
    FLOPS_half_precision = (inst_hadd .+ inst_hmul .+ inst_hfma) .* gpu_freq_hz
    FLOPS_tensor_core =
        (
            tc_fp64 .+ tc_tf32 .+ tc_bf16 .+ tc_fp16 .+ tc_int1 .+ tc_int4 .+ tc_int8 .+
            tc_fp8_off .+ tc_fp8_on .+ tc_fp4 .+ tc_fp4_fp6_16 .+ tc_fp4_fp6_32 .+
            tc_fp4_fp6_fp8_16 .+ tc_fp4_fp6_fp8_32
        ) .* gpu_freq_hz
    FLOPS_total =
        FLOPS_double_precision .+ FLOPS_single_precision .+ FLOPS_half_precision .+
        FLOPS_tensor_core
    result = hcat(
        data,
        DataFrame(;
            FLOPS_double_precision=FLOPS_double_precision,
            FLOPS_single_precision=FLOPS_single_precision,
            FLOPS_half_precision=FLOPS_half_precision,
            FLOPS_tensor_core=FLOPS_tensor_core,
            FLOPS_total=FLOPS_total,
        );
        makeunique=true,
    )
    return result
end
compute_flops(filepath::String) =
    compute_flops(DataFrame(File(filepath; header=1, skipto=3)))

function safe_column(col)
    if eltype(col) <: AbstractString
        return [v == "no data" ? 0.0 : parse(Float64, v) for v in col]
    else
        return coalesce.(col, 0.0)
    end
end
