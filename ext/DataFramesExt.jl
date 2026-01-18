module DataFramesExt

using DataFrames: DataFrame
using Tables: rows

import NsightCompute: compute_flops, compute_ai

compute_flops(data::DataFrame, peak=false) = DataFrame(compute_flops(rows(data), peak))

compute_ai(data::DataFrame, peak=false) = DataFrame(compute_ai(rows(data), peak))

end
