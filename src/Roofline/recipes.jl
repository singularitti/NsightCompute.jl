using RecipesBase: @recipe, @series, @userplot

@userplot RooflinePlot
@recipe function f(plot::RooflinePlot)
    xscale --> :log10
    yscale --> :log10
    xlabel --> raw"arithmetic intensity (FLOP/byte)"
    ylabel --> raw"performance (TFLOP/s)"
    yformatter --> (y -> string(round(y / 10^12; sigdigits=3)))  # Convert FLOPs to TFLOPs
    # Support either `rooflineplot(table)` or `rooflineplot(table, peak=false)`
    table = only(plot.args)
    # Compute achieved AI and performance from the table
    ai_data = compute_ai(table, false)
    flops_data = compute_flops(table, false)
    # Peak/theoretical values (per-precision);
    peak_flops = compute_flops(table, true)
    # Peak DRAM bandwidth (TB/s) -> bytes/s
    dram_peak_tb = compute_dram_bandwidth(table, true)
    dram_peak_bytes = maximum(dram_peak_tb) * 10^12
    @assert !iszero(dram_peak_bytes)
    # Categories to plot: (AI field, FLOPS field, label)
    categories = (
        (:AI_fp64, :FLOPS_fp64, "double"),
        (:AI_fp32, :FLOPS_fp32, "single"),
        (:AI_fp16, :FLOPS_fp16, "half"),
    )
    for (index, (ai_name, flops_name, label)) in enumerate(categories)
        ai_datum = filter(ispositive, getproperty(ai_data, ai_name))
        flops_datum = filter(ispositive, getproperty(flops_data, flops_name))
        peak_vals = filter(ispositive, getproperty(peak_flops, flops_name))
        if isempty(ai_datum) || isempty(flops_datum) || isempty(peak_vals)
            throw(
                DomainError(
                    """
                    no positive values found in AI, FLOPS, or peak FLOPS data for category $label.
                    Roofline plot requires positive values for log-log scale.
                    """
                ),
            )
        end
        peak_val = maximum(peak_vals)
        ai_ridge = peak_val / dram_peak_bytes
        ai_min = min(minimum(ai_datum), ai_ridge) / 1000
        ai_max = max(maximum(ai_datum), ai_ridge) * 1000
        ai_before_ridge = [ai_min, ai_ridge]
        ai_after_ridge = [ai_ridge, ai_max]
        # Horizontal roofline (peak FLOP/s)
        @series begin
            seriestype --> :path
            seriescolor --> index
            linestyle --> :dash
            primary := false
            ai_before_ridge, fill(peak_val, length(ai_before_ridge))
        end
        @series begin
            seriestype --> :path
            seriescolor --> index
            linestyle --> :solid
            primary := false
            ai_after_ridge, fill(peak_val, length(ai_after_ridge))
        end
        # Memory-bound roofline (bandwidth slope)
        @series begin
            seriestype --> :path
            seriescolor --> index
            linestyle --> :solid
            primary := false
            ai_before_ridge, ai_before_ridge .* dram_peak_bytes
        end
        @series begin
            seriestype --> :path
            seriescolor --> index
            linestyle --> :dash
            primary := false
            ai_after_ridge, ai_after_ridge .* dram_peak_bytes
        end
        @series begin
            seriestype := :scatter
            label --> label
            seriescolor --> index
            ai_datum, flops_datum
        end
    end
end

@userplot FlopsPlot
@recipe function f(plot::FlopsPlot; stacked=false)
    xlabel --> "step"
    ylabel --> raw"performance (TFLOP/s)"
    yformatter --> (y -> string(round(y / 10^12; sigdigits=3)))  # Convert FLOPs to TFLOPs
    fillalpha --> 0.2
    z_order := :back
    table, peak = plot.args
    flops = compute_flops(table, peak)
    steps = 1:_nrows(table)
    xlims --> extrema(steps)
    ylims --> (0, :auto)
    categories = (
        (:FLOPS_fp64, "double"),
        (:FLOPS_fp32, "single"),
        (:FLOPS_fp16, "half"),
        (:FLOPS_tensor_core, "tensor"),
        (:FLOPS_total, "total"),
    )
    if stacked
        n = length(steps)
        cumulative = zeros(n)
        for (category_name, label) in categories
            if category_name == :FLOPS_total
                continue  # Skip total when stacking
            end
            if hasproperty(flops, category_name)
                vals = coalesce.(getproperty(flops, category_name), 0.0)
                top = cumulative .+ vals
                @series begin
                    seriestype --> :path
                    label --> label
                    fillrange --> cumulative
                    steps, top
                end
                cumulative = top
            end
        end
    else
        for (category_name, label) in categories
            if hasproperty(flops, category_name)
                vals = getproperty(flops, category_name)
                @series begin
                    seriestype --> :path
                    label --> label
                    fillrange --> zeros(length(vals))
                    steps, vals
                end
            end
        end
    end
end

@userplot AiPlot
@recipe function f(plot::AiPlot)
    xlabel --> "step"
    ylabel --> raw"arithmetic intensity (FLOP/byte)"
    fillalpha --> 0.2
    table, peak = plot.args
    ai = compute_ai(table, peak)
    steps = 1:_nrows(table)
    xlims --> extrema(steps)
    ylims --> (0, :auto)
    categories = ((:AI_fp64, "double"), (:AI_fp32, "single"), (:AI_fp16, "half"))
    for (category_name, label) in categories
        if hasproperty(ai, category_name)
            vals = getproperty(ai, category_name)
            @series begin
                seriestype --> :path
                label --> label
                fillrange --> zeros(length(vals))
                steps, vals
            end
        end
    end
end

# Helper: compute per-category percentage vectors and per-step totals
function _compute_percentage_map(flops, categories, n)
    total_per_step = zeros(n)
    per_category_values = Dict{Symbol,Vector{Float64}}()
    for (category_name, _) in categories
        if hasproperty(flops, category_name)
            values = coalesce.(getproperty(flops, category_name), 0.0)
            per_category_values[category_name] = values
            total_per_step .+= values
        end
    end
    if all(iszero, total_per_step)
        return Dict{Symbol,Vector{Float64}}(), total_per_step
    end
    per_category_percent = Dict{Symbol,Vector{Float64}}()
    nonzero_mask = total_per_step .> zero(total_per_step)
    for (category_name, _) in categories
        if haskey(per_category_values, category_name)
            values = per_category_values[category_name]
            percent = zeros(n)
            percent[nonzero_mask] .= 100 .* values[nonzero_mask] ./ total_per_step[nonzero_mask]
            per_category_percent[category_name] = percent
        end
    end
    return per_category_percent, total_per_step
end

@userplot FlopsPercentagePlot
@recipe function f(plot::FlopsPercentagePlot)
    xlabel --> "step"
    ylabel --> raw"performance percentage (%)"
    ylims --> (0, 100)
    fillalpha --> 0.6
    linewidth --> 0
    table, peak = plot.args
    flops = compute_flops(table, peak)
    n = _nrows(table)
    steps = 1:n
    xlims --> extrema(steps)
    categories = (
        (:FLOPS_fp64, "double"),
        (:FLOPS_fp32, "single"),
        (:FLOPS_fp16, "half"),
        (:FLOPS_tensor_core, "tensor"),
    )
    # Collect numeric values and compute per-step denominators using helper
    per_category_percent, _ = _compute_percentage_map(flops, categories, n)
    if isempty(per_category_percent)
        return nothing
    end
    stacked_base = zeros(n)
    for (category_name, label) in categories
        if haskey(per_category_percent, category_name)
            percent = per_category_percent[category_name]
            top = stacked_base .+ percent
            @series begin
                seriestype --> :path
                label --> label
                fillrange --> stacked_base
                steps, top
            end
            stacked_base = top
        end
    end
    # Fill any remaining percentage with `none` (e.g., when denom == 0)
    remainder_percent = 100 .- stacked_base
    if any(remainder_percent .> 0)
        top = stacked_base .+ remainder_percent
        @series begin
            seriestype --> :path
            label --> "none"
            fillrange --> stacked_base
            steps, top
        end
    end
end
