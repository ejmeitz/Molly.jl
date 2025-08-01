export Mie

@doc raw"""
    Mie(; m, n, cutoff, use_neighbors, shortcut, σ_mixing, ϵ_mixing, weight_special)

The Mie generalized interaction between two atoms.

When `m` equals 6 and `n` equals 12 this is equivalent to the Lennard-Jones interaction.
The potential energy is defined as
```math
V(r_{ij}) = C \varepsilon_{ij} \left[\left(\frac{\sigma_{ij}}{r_{ij}}\right)^n - \left(\frac{\sigma_{ij}}{r_{ij}}\right)^m\right]
```
where
```math
C = \frac{n}{n - m} \left( \frac{n}{m} \right) ^\frac{m}{n - m}
```
"""
struct Mie{T, W, C, H, S, E} <: PairwiseInteraction
    m::T
    n::T
    cutoff::C
    use_neighbors::Bool
    shortcut::H
    σ_mixing::S
    ϵ_mixing::E
    weight_special::W
    mn_fac::T
end

function Mie(;
                m,
                n,
                cutoff=NoCutoff(),
                use_neighbors=false,
                shortcut=lj_zero_shortcut,
                σ_mixing=lorentz_σ_mixing,
                ϵ_mixing=geometric_ϵ_mixing,
                weight_special=1)
    m_p, n_p, mn_fac = promote(m, n, (n / (n - m)) * (n / m) ^ (m / (n - m)))
    return Mie(m_p, n_p, cutoff, use_neighbors, shortcut, σ_mixing, ϵ_mixing,
               weight_special, mn_fac)
end

use_neighbors(inter::Mie) = inter.use_neighbors

function Base.zero(m::Mie{T, W}) where {T, W}
    return Mie(zero(T), zero(T), m.cutoff, m.use_neighbors, m.shortcut, m.σ_mixing,
               m.ϵ_mixing, zero(W), zero(T))
end

function Base.:+(m1::Mie, m2::Mie)
    return Mie(
        m1.m + m2.m,
        m1.n + m2.n,
        m1.cutoff,
        m1.use_neighbors,
        m1.shortcut,
        m1.σ_mixing,
        m1.ϵ_mixing,
        m1.weight_special + m2.weight_special,
        m1.mn_fac + m2.mn_fac,
    )
end

@inline function force(inter::Mie,
                       dr,
                       atom_i,
                       atom_j,
                       force_units=u"kJ * mol^-1 * nm^-1",
                       special=false,
                       args...)
    if inter.shortcut(atom_i, atom_j)
        return ustrip.(zero(dr)) * force_units
    end
    σ = inter.σ_mixing(atom_i, atom_j)
    ϵ = inter.ϵ_mixing(atom_i, atom_j)

    cutoff = inter.cutoff
    r2 = sum(abs2, dr)
    r = √r2
    m = inter.m
    n = inter.n
    const_mn = inter.mn_fac * ϵ
    σ_r = σ / r
    params = (m, n, σ_r, const_mn)

    f = force_divr_with_cutoff(inter, r2, params, cutoff, force_units)
    if special
        return f * dr * inter.weight_special
    else
        return f * dr
    end
end

function force_divr(::Mie, r2, invr2, (m, n, σ_r, const_mn))
    return -const_mn / r2 * (m * σ_r ^ m - n * σ_r ^ n)
end

@inline function potential_energy(inter::Mie,
                                  dr,
                                  atom_i,
                                  atom_j,
                                  energy_units=u"kJ * mol^-1",
                                  special=false,
                                  args...)
    if inter.shortcut(atom_i, atom_j)
        return ustrip(zero(dr[1])) * energy_units
    end
    σ = inter.σ_mixing(atom_i, atom_j)
    ϵ = inter.ϵ_mixing(atom_i, atom_j)

    cutoff = inter.cutoff
    r2 = sum(abs2, dr)
    r = √r2
    m = inter.m
    n = inter.n
    const_mn = inter.mn_fac * ϵ
    σ_r = σ / r
    params = (m, n, σ_r, const_mn)

    pe = potential_with_cutoff(inter, r2, params, cutoff, energy_units)
    if special
        return pe * inter.weight_special
    else
        return pe
    end
end

function potential(::Mie, r2, invr2, (m, n, σ_r, const_mn))
    return const_mn * (σ_r ^ n - σ_r ^ m)
end
