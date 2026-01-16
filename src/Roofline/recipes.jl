using RecipesBase: @recipe, @series, @userplot

@userplot RooflinePlot
@recipe function f(plot::RooflinePlot)
    xscale --> :log10
    yscale --> :log10
    xlabel --> raw"arithmetic intensity (FLOP/byte)"
    ylabel --> raw"performance (TFLOP/s)"
    yformatter --> (y -> string(round(y / 10^12; sigdigits=3)))  # Convert FLOPs to TFLOPs
    table = only(plot.args)
    # compute AI and achieved performance from the table
    ai_data = compute_ai(table)
    flops_data = compute_flops(table)
    # categories to plot: (AI field, FLOPS field, label)
    types = (
        (:AI_double_precision, :FLOPS_double_precision, "double"),
        (:AI_single_precision, :FLOPS_single_precision, "single"),
        (:AI_half_precision, :FLOPS_half_precision, "half"),
    )
    for (ai_type, flops_type, label) in types
        if hasproperty(ai_data, ai_type) && hasproperty(flops_data, flops_type)
            ai_datum = getproperty(ai_data, ai_type)
            flops_datum = getproperty(flops_data, flops_type)
            # filter positive values for log-log plot (infinite values are assumed impossible)
            mask = (ai_datum .> 0) .& (flops_datum .> 0)
            if any(mask)
                @series begin
                    seriestype := :scatter
                    label --> label
                    ai_datum[mask], flops_datum[mask]
                end
            end
        end
    end
end

@userplot FlopsPlot
@recipe function f(plot::FlopsPlot)
    xlabel --> "step"
    ylabel --> raw"performance (TFLOP/s)"
    yformatter --> (y -> string(round(y / 10^12; sigdigits=3)))  # Convert FLOPs to TFLOPs
    fillalpha --> 0.2
    z_order := :back
    table = only(plot.args)
    flops = compute_flops(table)
    steps = 1:_nrows(table)
    xlims --> extrema(steps)
    ylims --> (0, :auto)
    types = (
        (:FLOPS_double_precision, "double"),
        (:FLOPS_single_precision, "single"),
        (:FLOPS_half_precision, "half"),
        (:FLOPS_tensor_core, "tensor"),
        (:FLOPS_total, "total"),
    )
    stacked = get(plotattributes, :stacked, false)
    if stacked
        n = length(steps)
        cumulative = zeros(n)
        for (sym, label) in types
            if sym == :FLOPS_total
                continue  # Skip total when stacking
            end
            if hasproperty(flops, sym)
                vals = coalesce.(getproperty(flops, sym), 0.0)
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
        for (sym, label) in types
            if hasproperty(flops, sym)
                vals = getproperty(flops, sym)
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

@userplot FlopsPercentagePlot
@recipe function f(plot::FlopsPercentagePlot)
    xlabel --> "step"
    ylabel --> raw"percentage (%)"
    ylims --> (0, 100)
    table = only(plot.args)
    flops = compute_flops(table)
    n = _nrows(table)
    steps = 1:n
    xlims --> extrema(steps)

    types = (
        (:FLOPS_double_precision, "double"),
        (:FLOPS_single_precision, "single"),
        (:FLOPS_half_precision, "half"),
        (:FLOPS_tensor_core, "tensor"),
    )
    # collect numeric values and compute per-step denominators
    denom = zeros(n)
    vals_map = Dict{Symbol,Vector{Float64}}()
    for (sym, _) in types
        if hasproperty(flops, sym)
            v = float.(coalesce.(getproperty(flops, sym), 0.0))
            vals_map[sym] = v
            denom .+= v
        end
    end
    if all(iszero, denom)
        return nothing
    end
    # compute percentage vectors per category
    perc_map = Dict{Symbol,Vector{Float64}}()
    for (sym, _) in types
        if haskey(vals_map, sym)
            v = vals_map[sym]
            perc = zeros(n)
            nz = denom .> 0
            perc[nz] .= 100 .* v[nz] ./ denom[nz]
            perc_map[sym] = perc
        end
    end
    # stack and plot categories
    cumulative = zeros(n)
    j = 1
    for (sym, label) in types
        if haskey(perc_map, sym)
            perc = perc_map[sym]
            top = cumulative .+ perc
            @series begin
                seriestype --> :path
                label --> label
                color --> j
                fillrange --> cumulative
                fillalpha --> 0.6
                steps, top
            end
            cumulative = top
            j += 1
        end
    end
    # fill any remaining percentage with `none` (e.g., when denom == 0)
    rem = 100 .- cumulative
    if any(rem .> 0)
        top = cumulative .+ rem
        @series begin
            seriestype --> :path
            label --> "none"
            color --> j
            fillrange --> cumulative
            fillalpha --> 0.6
            steps, top
        end
    end
end
