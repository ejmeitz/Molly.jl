# Radial distribution function
# This file is only loaded when KernelDensity is imported

module MollyKernelDensityExt

using Molly
using KernelDensity

function Molly.rdf(coords, boundary; npoints::Integer=200)
    n_atoms = length(coords)
    dims = length(first(coords))
    dists = distances(coords, boundary)
    dists_vec = [dists[i, j] for i in 1:n_atoms, j in 1:n_atoms if j > i]
    dist_unit = unit(first(dists_vec))
    kd = kde(ustrip.(dists_vec); npoints=npoints)
    ρ = n_atoms / volume(boundary)
    T = float_type(boundary)
    if dims == 3
        normalizing_factor = 4 .* T(π) .* ρ .* step(kd.x) .* kd.x .^ 2 .* dist_unit .^ 3
    elseif dims == 2
        normalizing_factor = 2 .* T(π) .* ρ .* step(kd.x) .* kd.x .* dist_unit .^ 2
    end
    bin_centers = collect(kd.x) .* dist_unit
    density_weighted = kd.density ./ normalizing_factor
    return bin_centers, density_weighted
end

end
