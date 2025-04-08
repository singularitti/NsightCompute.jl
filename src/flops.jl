export compute_flops

function compute_flops(filepath::String)
    df = CSV.read(filepath, DataFrame; header=1, skipto=3)
    # GPU frequency (Hz) from SM average frequency (GHz)
    gpu_freq_hz = df[:, "sm__cycles_elapsed.avg.per_second"] .* 10^9
    # Instruction counts per cycle (inst/cycle), double precision
    inst_dadd = df[
        :, "smsp__sass_thread_inst_executed_op_dadd_pred_on.sum.per_cycle_elapsed"
    ]
    inst_dmul = df[
        :, "smsp__sass_thread_inst_executed_op_dmul_pred_on.sum.per_cycle_elapsed"
    ]
    inst_dfma = df[
        :, "smsp__sass_thread_inst_executed_op_dfma_pred_on.sum.per_cycle_elapsed"
    ]
    # Single precision
    inst_fadd = df[
        :, "smsp__sass_thread_inst_executed_op_fadd_pred_on.sum.per_cycle_elapsed"
    ]
    inst_fmul = df[
        :, "smsp__sass_thread_inst_executed_op_fmul_pred_on.sum.per_cycle_elapsed"
    ]
    inst_ffma = df[
        :, "smsp__sass_thread_inst_executed_op_ffma_pred_on.sum.per_cycle_elapsed"
    ]
    # Half precision
    inst_hfma = df[
        :, "smsp__sass_thread_inst_executed_op_hfma_pred_on.sum.per_cycle_elapsed"
    ]
    FLOPS_double_precision = (inst_dfma .* 2 .+ inst_dadd .+ inst_dmul) .* gpu_freq_hz
    FLOPS_single_precision = (inst_ffma .* 2 .+ inst_fadd .+ inst_fmul) .* gpu_freq_hz
    FLOPS_half_precision = (inst_hfma .* 2) .* gpu_freq_hz
    FLOPS_total = FLOPS_double_precision .+ FLOPS_single_precision .+ FLOPS_half_precision
    flops_df = DataFrame(;
        FLOPS_double_precision=FLOPS_double_precision,
        FLOPS_single_precision=FLOPS_single_precision,
        FLOPS_half_precision=FLOPS_half_precision,
        FLOPS_total=FLOPS_total,
    )
    return flops_df
end
