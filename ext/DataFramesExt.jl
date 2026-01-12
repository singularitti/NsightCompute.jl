module DataFramesExt

using DataFrames: DataFrame

import NsightCompute: compute_flops

compute_flops(data::DataFrame) = DataFrame(compute_flops(data))

end
