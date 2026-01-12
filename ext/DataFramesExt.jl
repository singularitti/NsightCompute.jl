module DataFramesExt

using DataFrames: DataFrame
using Tables: rows

import NsightCompute: compute_flops

compute_flops(data::DataFrame) = DataFrame(compute_flops(rows(data)))

end
