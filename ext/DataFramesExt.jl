module DataFramesExt

using DataFrames: DataFrame
using Tables: rows

import NsightCompute: compute_flops, compute_ai

compute_flops(data::DataFrame) = DataFrame(compute_flops(rows(data)))

compute_ai(data::DataFrame) = DataFrame(compute_ai(rows(data)))

end
