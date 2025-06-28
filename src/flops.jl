using CSV: File
using DataFrames: hcat

export compute_flops

function compute_flops(data::DataFrame)
    # GPU frequency (Hz) from SM average frequency (GHz)
    gpu_freq_hz = data[:, "smsp__cycles_elapsed.avg.per_second"] .* 10^9
    # Instruction counts per cycle (inst/cycle), double precision
    inst_dadd = data[
        :, "smsp__sass_thread_inst_executed_op_dadd_pred_on.sum.per_cycle_elapsed"
    ]
    inst_dmul = data[
        :, "smsp__sass_thread_inst_executed_op_dmul_pred_on.sum.per_cycle_elapsed"
    ]
    inst_dfma = data[:, "derived__smsp__sass_thread_inst_executed_op_dfma_pred_on_x2"]
    # Single precision
    inst_fadd = data[
        :, "smsp__sass_thread_inst_executed_op_fadd_pred_on.sum.per_cycle_elapsed"
    ]
    inst_fmul = data[
        :, "smsp__sass_thread_inst_executed_op_fmul_pred_on.sum.per_cycle_elapsed"
    ]
    inst_ffma = data[:, "derived__smsp__sass_thread_inst_executed_op_ffma_pred_on_x2"]
    # Half precision
    inst_hfma = data[:, "derived__smsp__sass_thread_inst_executed_op_hfma_pred_on_x4"]
    FLOPS_double_precision = (inst_dfma .+ inst_dadd .+ inst_dmul) .* gpu_freq_hz
    FLOPS_single_precision = (inst_ffma .+ inst_fadd .+ inst_fmul) .* gpu_freq_hz
    FLOPS_half_precision = inst_hfma .* gpu_freq_hz
    FLOPS_total = FLOPS_double_precision .+ FLOPS_single_precision .+ FLOPS_half_precision
    result = hcat(
        data,
        DataFrame(;
            FLOPS_double_precision=FLOPS_double_precision,
            FLOPS_single_precision=FLOPS_single_precision,
            FLOPS_half_precision=FLOPS_half_precision,
            FLOPS_total=FLOPS_total,
        );
        makeunique=true,
    )
    return result
end
compute_flops(filepath::String) =
    compute_flops(DataFrame(File(filepath; header=1, skipto=3)))
