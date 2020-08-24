"""
    LennardJones(nl_only)

The Lennard-Jones 6-12 interaction.
"""
struct LennardJones{S, C} <: GeneralInteraction
    cutoff::C
    nl_only::Bool
end

LennardJones{S}(cutoff, nl_only) where S =
    LennardJones{S, typeof(cutoff)}(cutoff, nl_only)

LennardJones(cutoff, nl_only) =
    LennardJones{false, typeof(cutoff)}(cutoff, nl_only)

LennardJones(nl_only=false) =
    LennardJones(ShiftedPotentialCutoff(3.0), nl_only)

@inline @inbounds function force(inter::LennardJones{S, C},
                                 coord_i,
                                 coord_j,
                                 atom_i,
                                 atom_j,
                                 i::Integer,
                                 j::Integer,
                                 box_size) where {S, C}
    i == j && return zero(coord_i) # TODO: get rid of this check
    dr = vector(coord_i, coord_j, box_size)
    r2 = sum(abs2, dr)

    if !S && iszero(atom_i.σ) || iszero(atom_j.σ)
        return zero(coord_i)
    end

    σ = sqrt(atom_i.σ * atom_j.σ)
    ϵ = sqrt(atom_i.ϵ * atom_j.ϵ)

    cutoff = inter.cutoff
    σ2 = σ^2
    params = (σ2, ϵ)

    if cutoff_points(C) == 0
        f = force_nocutoff(inter, r2, inv(r2), params)
    elseif cutoff_points(C) == 1
        sqdist_cutoff = cutoff.sqdist_cutoff * σ2
        r2 > sqdist_cutoff && return zero(coord_i)

        f = force_cutoff(cutoff, r2, inter, params)
    elseif cutoff_points(C) == 2
        sqdist_cutoff = cutoff.sqdist_cutoff * σ2
        activation_dist = cutoff.activation_dist * σ2

        r2 > sqdist_cutoff && return zero(coord_i)

        if r2 < activation_dist
            f = force_nocutoff(inter, r2, inv(r2), params)
        else
            f = force_cutoff(cutoff, r2, inter, params)
        end
    end

    return f * dr
end

@fastmath function force_nocutoff(::LennardJones, r2, invr2, (σ2, ϵ))
    six_term = (σ2 * invr2) ^ 3

    return (24ϵ * invr2) * (2 * six_term ^ 2 - six_term)
end

@inline @inbounds function potential_energy(inter::LennardJones{S, C},
                                            s::Simulation,
                                            i::Integer,
                                            j::Integer) where {S, C}
    U = eltype(s.coords[i]) # this is not Unitful compatible
    i == j && return zero(U)

    dr = vector(s.coords[i], s.coords[j], s.box_size)
    r2 = sum(abs2, dr)

    if !S && iszero(s.atoms[i].σ) || iszero(s.atoms[j].σ)
        return zero(U)
    end

    σ = sqrt(s.atoms[i].σ * s.atoms[j].σ)
    ϵ = sqrt(s.atoms[i].ϵ * s.atoms[j].ϵ)

    cutoff = inter.cutoff
    σ2 = σ^2
    params = (σ2, ϵ)

    if cutoff_points(C) == 0
        potential(inter, r2, inv(r2), params)
    elseif cutoff_points(C) == 1
        sqdist_cutoff = cutoff.sqdist_cutoff * σ2
        r2 > sqdist_cutoff && return zero(U)

        potential_cutoff(cutoff, r2, inter, params)
    elseif cutoff_points(C) == 2
        r2 > sqdist_cutoff && return zero(U)

        if r2 < activation_dist
            potential(inter, r2, inv(r2), params)
        else
            potential_cutoff(cutoff, r2, inter, params)
        end
    end
end

@fastmath function potential(::LennardJones, r2, invr2, (σ2, ϵ))
    six_term = (σ2 * invr2) ^ 3

    return 4ϵ * (six_term ^ 2 - six_term)
end
