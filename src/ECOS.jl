#############################################################################
# ECOS.jl
# Wrapper around the ECOS solver https://github.com/ifa-ethz/ecos
# See http://github.com/jump-dev/ECOS.jl
#############################################################################
# ECOS.jl
# Contains the wrapper itself
#############################################################################

module ECOS

import ECOS_jll
const ecos = ECOS_jll.libecos

using CEnum

include("gen/libecos_common.jl")
include("gen/libecos_api.jl")

"""
    unsafe_add_settings(p::Ptr{pwork}, options::Dict{Symbol})

Add settings to the ECOS model.
"""
function unsafe_add_settings(p::Ptr{pwork}, options::Dict{Symbol})
    problem = unsafe_load(p)::pwork
    stgs = unsafe_load(problem.stgs)::settings
    new_stgs = settings(
        [get(options, k, getfield(stgs, k)) for k in fieldnames(settings)]...,
    )
    unsafe_store!(problem.stgs, new_stgs)
    return
end

include("MOI_wrapper/MOI_wrapper.jl")

function __init__()
    libecos_version = VersionNumber(unsafe_string(ECOS_ver()))
    if libecos_version != v"2.0.8"
        error(
            "Current ECOS version installed is $(libecos_version), but we " *
            "require version 2.0.8",
        )
    end
    return
end

end # module
