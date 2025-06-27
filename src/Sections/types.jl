using Base: @kwdef
using StructTypes: StructTypes, Struct

const Maybe{T} = Union{T,Nothing}

@kwdef struct CollectionFilter
    CollectionScopes::Maybe{String} = nothing
end
StructTypes.StructType(::Type{CollectionFilter}) = Struct()

@kwdef struct FilterDef
    MinArch::Maybe{String} = nothing
    MaxArch::Maybe{String} = nothing
    CollectionFilter::Maybe{CollectionFilter} = nothing
end
StructTypes.StructType(::Type{FilterDef}) = Struct()

@kwdef struct Option
    Name::Maybe{String} = nothing
    Filter::Maybe{FilterDef} = nothing
end
StructTypes.StructType(::Type{Option}) = Struct()

@kwdef struct Metric
    Label::Maybe{String} = nothing
    Name::Maybe{String} = nothing
    Filter::Maybe{FilterDef} = nothing
    Options::Maybe{Vector{Option}} = nothing
end
StructTypes.StructType(::Type{Metric}) = Struct()

# Wrapper to handle the `Metrics { Metrics { ... } }` nesting
@kwdef struct MetricsWrapper
    Metrics::Maybe{Vector{Metric}} = nothing
end
StructTypes.StructType(::Type{MetricsWrapper}) = Struct()

@kwdef struct MetricDefinition
    Name::Maybe{String} = nothing
    Expression::Maybe{String} = nothing
    Filter::Maybe{FilterDef} = nothing
end
StructTypes.StructType(::Type{MetricDefinition}) = Struct()

# Wrapper to handle the `MetricDefinitions { MetricDefinitions { ... } }` nesting
@kwdef struct MetricDefinitionsWrapper
    MetricDefinitions::Maybe{Vector{MetricDefinition}} = nothing
end
StructTypes.StructType(::Type{MetricDefinitionsWrapper}) = Struct()

@kwdef struct Axis
    Label::Maybe{String} = nothing
end
StructTypes.StructType(::Type{Axis}) = Struct()

@kwdef struct CyclesPerSecondMetric
    Label::Maybe{String} = nothing
    Name::Maybe{String} = nothing
    Filter::Maybe{FilterDef} = nothing
    Options::Maybe{Vector{Option}} = nothing
end
StructTypes.StructType(::Type{CyclesPerSecondMetric}) = Struct()

@kwdef struct ValuePerCycleMetric
    Label::Maybe{String} = nothing
    Name::Maybe{String} = nothing
    Filter::Maybe{FilterDef} = nothing
    Options::Maybe{Vector{Option}} = nothing
end
StructTypes.StructType(::Type{ValuePerCycleMetric}) = Struct()

@kwdef struct ValueCyclesPerSecondExpression
    ValuePerCycleMetrics::Maybe{Vector{ValuePerCycleMetric}} = nothing
    CyclesPerSecondMetric::Maybe{CyclesPerSecondMetric} = nothing
end
StructTypes.StructType(::Type{ValueCyclesPerSecondExpression}) = Struct()

@kwdef struct PeakWork
    ValueCyclesPerSecondExpression::Maybe{ValueCyclesPerSecondExpression} = nothing
end
StructTypes.StructType(::Type{PeakWork}) = Struct()

@kwdef struct PeakTraffic
    ValueCyclesPerSecondExpression::Maybe{ValueCyclesPerSecondExpression} = nothing
end
StructTypes.StructType(::Type{PeakTraffic}) = Struct()

@kwdef struct RooflineOptions
    Label::Maybe{String} = nothing
end
StructTypes.StructType(::Type{RooflineOptions}) = Struct()

@kwdef struct Roofline
    PeakWork::Maybe{PeakWork} = nothing
    PeakTraffic::Maybe{PeakTraffic} = nothing
    Options::Maybe{RooflineOptions} = nothing
end
StructTypes.StructType(::Type{Roofline}) = Struct()

@kwdef struct AchievedMetric
    Label::Maybe{String} = nothing
    Name::Maybe{String} = nothing
    Filter::Maybe{FilterDef} = nothing
    Options::Maybe{Vector{Option}} = nothing
end
StructTypes.StructType(::Type{AchievedMetric}) = Struct()

@kwdef struct AchievedTraffic
    Metric::Maybe{AchievedMetric} = nothing
end
StructTypes.StructType(::Type{AchievedTraffic}) = Struct()

@kwdef struct AchievedWork
    ValueCyclesPerSecondExpression::Maybe{ValueCyclesPerSecondExpression} = nothing
end
StructTypes.StructType(::Type{AchievedWork}) = Struct()

@kwdef struct AchievedValues
    AchievedWork::Maybe{AchievedWork} = nothing
    AchievedTraffic::Maybe{AchievedTraffic} = nothing
    Options::Maybe{RooflineOptions} = nothing
end
StructTypes.StructType(::Type{AchievedValues}) = Struct()

@kwdef struct RooflineChart
    Label::Maybe{String} = nothing
    AxisIntensity::Maybe{Axis} = nothing
    AxisWork::Maybe{Axis} = nothing
    Rooflines::Maybe{Vector{Roofline}} = nothing
    AchievedValues::Maybe{Vector{AchievedValues}} = nothing
end
StructTypes.StructType(::Type{RooflineChart}) = Struct()

@kwdef struct ChartItem
    RooflineChart::Maybe{RooflineChart} = nothing
end
StructTypes.StructType(::Type{ChartItem}) = Struct()

# This wrapper is added to correctly model the structure `Items { RooflineChart { ... } }`
@kwdef struct ItemsWrapper
    RooflineChart::Maybe{RooflineChart} = nothing
end
StructTypes.StructType(::Type{ItemsWrapper}) = Struct()

@kwdef struct Body
    DisplayName::Maybe{String} = nothing
    # The `Items` field now correctly points to the wrapper struct
    Items::Maybe{ItemsWrapper} = nothing
end
StructTypes.StructType(::Type{Body}) = Struct()

@kwdef struct SetItem
    Identifier::Maybe{String} = nothing
end
StructTypes.StructType(::Type{SetItem}) = Struct()

# --- The Root Type for the Entire File ---

@kwdef struct ProfilerReport
    Identifier::String # A root identifier is rarely optional, keep as required.
    DisplayName::Maybe{String} = nothing
    Extends::Maybe{String} = nothing
    Description::Maybe{String} = nothing
    Order::Maybe{Int} = nothing
    Sets::Maybe{Vector{SetItem}} = nothing
    Filter::Maybe{FilterDef} = nothing
    Metrics::Maybe{MetricsWrapper} = nothing
    MetricDefinitions::Maybe{MetricDefinitionsWrapper} = nothing
    Body::Maybe{Body} = nothing
end
StructTypes.StructType(::Type{ProfilerReport}) = Struct()
