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
    table = only(plot.args)
    flops = compute_flops(table)
    steps = 1:_nrows(table)
    xlims --> extrema(steps)
    types = (
        (:FLOPS_double_precision, "double"),
        (:FLOPS_single_precision, "single"),
        (:FLOPS_half_precision, "half"),
        (:FLOPS_tensor_core, "tensor"),
        (:FLOPS_total, "total"),
    )
    for (sym, label) in types
        if hasproperty(flops, sym)
            vals = getproperty(flops, sym)
            @series begin
                seriestype --> :path
                label --> label
                fillrange --> zeros(length(vals))
                fillalpha --> 0.1
                z_order := :back
                steps, vals
            end
        end
    end
    return nothing
end
