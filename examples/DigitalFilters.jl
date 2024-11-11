module DigitalFilters

using DataStructures

include("readers.jl")

include("iir_filter.jl")
include("diff_filter.jl")
include("slidemean_filter.jl")

export DiffFilter, SlideMeanFilter

end
