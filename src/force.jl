# See https://arxiv.org/pdf/1401.1181.pdf for applying forces to atoms
# See OpenMM documentation and Gromacs manual for other aspects of forces

export
    accelerations,
    force,
    SpecificForce1Atoms,
    SpecificForce2Atoms,
    SpecificForce3Atoms,
    SpecificForce4Atoms,
    forces

"""
    accelerations(system, neighbors=find_neighbors(sys); n_threads=Threads.nthreads())

Calculate the accelerations of all atoms in a system using the pairwise,
specific and general interactions and Newton's second law of motion.
"""
function accelerations(sys; n_threads::Integer=Threads.nthreads())
    return accelerations(sys, find_neighbors(sys; n_threads=n_threads); n_threads=n_threads)
end

function accelerations(sys, neighbors; n_threads::Integer=Threads.nthreads())
    return forces(sys, neighbors; n_threads=n_threads) ./ masses(sys)
end

"""
    force(inter::PairwiseInteraction, vec_ij, atom_i, atom_j, force_units, special,
          coord_i, coord_j, boundary, velocity_i, velocity_j, step_n)
    force(inter::SpecificInteraction, coord_i, coord_j,
          boundary)
    force(inter::SpecificInteraction, coord_i, coord_j,
          coord_k, boundary)
    force(inter::SpecificInteraction, coord_i, coord_j,
          coord_k, coord_l, boundary)

Calculate the force between atoms due to a given interaction type.

For [`PairwiseInteraction`](@ref)s returns a single force vector and for
[`SpecificInteraction`](@ref)s returns a type such as [`SpecificForce2Atoms`](@ref).
Custom pairwise and specific interaction types should implement this function.
"""
function force end

# Allow GPU-specific force functions to be defined if required
force_gpu(inter::PairwiseInteraction, dr, ai, aj, fu, sp, ci, cj, bnd, vi, vj, sn) = force(inter, dr, ai, aj, fu, sp, ci, cj, bnd, vi, vj, sn)
force_gpu(inter::SpecificInteraction, ci, bnd)             = force(inter, ci, bnd)
force_gpu(inter::SpecificInteraction, ci, cj, bnd)         = force(inter, ci, cj, bnd)
force_gpu(inter::SpecificInteraction, ci, cj, ck, bnd)     = force(inter, ci, cj, ck, bnd)
force_gpu(inter::SpecificInteraction, ci, cj, ck, cl, bnd) = force(inter, ci, cj, ck, cl, bnd)

"""
    SpecificForce1Atoms(f1)

Force on one atom arising from an interaction such as a position restraint.
"""
struct SpecificForce1Atoms{D, T}
    f1::SVector{D, T}
end

"""
    SpecificForce2Atoms(f1, f2)

Forces on two atoms arising from an interaction such as a bond potential.
"""
struct SpecificForce2Atoms{D, T}
    f1::SVector{D, T}
    f2::SVector{D, T}
end

"""
    SpecificForce3Atoms(f1, f2, f3)

Forces on three atoms arising from an interaction such as a bond angle potential.
"""
struct SpecificForce3Atoms{D, T}
    f1::SVector{D, T}
    f2::SVector{D, T}
    f3::SVector{D, T}
end

"""
    SpecificForce4Atoms(f1, f2, f3, f4)

Forces on four atoms arising from an interaction such as a torsion potential.
"""
struct SpecificForce4Atoms{D, T}
    f1::SVector{D, T}
    f2::SVector{D, T}
    f3::SVector{D, T}
    f4::SVector{D, T}
end

function SpecificForce1Atoms(f1::StaticArray{Tuple{D}, T}) where {D, T}
    return SpecificForce1Atoms{D, T}(f1)
end

function SpecificForce2Atoms(f1::StaticArray{Tuple{D}, T}, f2::StaticArray{Tuple{D}, T}) where {D, T}
    return SpecificForce2Atoms{D, T}(f1, f2)
end

function SpecificForce3Atoms(f1::StaticArray{Tuple{D}, T}, f2::StaticArray{Tuple{D}, T},
                            f3::StaticArray{Tuple{D}, T}) where {D, T}
    return SpecificForce3Atoms{D, T}(f1, f2, f3)
end

function SpecificForce4Atoms(f1::StaticArray{Tuple{D}, T}, f2::StaticArray{Tuple{D}, T},
                            f3::StaticArray{Tuple{D}, T}, f4::StaticArray{Tuple{D}, T}) where {D, T}
    return SpecificForce4Atoms{D, T}(f1, f2, f3, f4)
end

Base.:+(x::SpecificForce1Atoms, y::SpecificForce1Atoms) = SpecificForce1Atoms(x.f1 + y.f1)
Base.:+(x::SpecificForce2Atoms, y::SpecificForce2Atoms) = SpecificForce2Atoms(x.f1 + y.f1, x.f2 + y.f2)
Base.:+(x::SpecificForce3Atoms, y::SpecificForce3Atoms) = SpecificForce3Atoms(x.f1 + y.f1, x.f2 + y.f2, x.f3 + y.f3)
Base.:+(x::SpecificForce4Atoms, y::SpecificForce4Atoms) = SpecificForce4Atoms(x.f1 + y.f1, x.f2 + y.f2, x.f3 + y.f3, x.f4 + y.f4)

"""
    forces(system, neighbors=find_neighbors(sys); n_threads=Threads.nthreads())

Calculate the forces on all atoms in a system using the pairwise, specific and
general interactions.
"""
function forces(sys; n_threads::Integer=Threads.nthreads())
    return forces(sys, find_neighbors(sys; n_threads=n_threads); n_threads=n_threads)
end

function forces(sys::System{D, false}, neighbors;
                n_threads::Integer=Threads.nthreads()) where D
    pairwise_inters_nonl = filter(!use_neighbors, values(sys.pairwise_inters))
    pairwise_inters_nl   = filter( use_neighbors, values(sys.pairwise_inters))
    sils_1_atoms = filter(il -> il isa InteractionList1Atoms, values(sys.specific_inter_lists))
    sils_2_atoms = filter(il -> il isa InteractionList2Atoms, values(sys.specific_inter_lists))
    sils_3_atoms = filter(il -> il isa InteractionList3Atoms, values(sys.specific_inter_lists))
    sils_4_atoms = filter(il -> il isa InteractionList4Atoms, values(sys.specific_inter_lists))

    fs = forces_pair_spec(sys.coords, sys.velocities, sys.atoms, pairwise_inters_nonl, pairwise_inters_nl,
                          sils_1_atoms, sils_2_atoms, sils_3_atoms, sils_4_atoms,
                          sys.boundary, sys.force_units, neighbors, n_threads)

    for inter in values(sys.general_inters)
        fs += AtomsCalculators.forces(sys, inter; neighbors=neighbors, n_threads=n_threads)
    end

    return fs
end

function forces_pair_spec(coords, velocities, atoms, pairwise_inters_nonl, pairwise_inters_nl,
                          sils_1_atoms, sils_2_atoms, sils_3_atoms, sils_4_atoms,
                          boundary, force_units, neighbors, n_threads)
    fs = ustrip_vec.(zero(coords))
    forces_pair_spec!(fs, coords, velocities, atoms, pairwise_inters_nonl, pairwise_inters_nl,
                      sils_1_atoms, sils_2_atoms, sils_3_atoms, sils_4_atoms, boundary,
                      force_units, neighbors, n_threads)
    return fs * force_units
end

function forces_pair_spec!(fs, coords, velocities, atoms, pairwise_inters_nonl, pairwise_inters_nl,
                                     sils_1_atoms, sils_2_atoms, sils_3_atoms, sils_4_atoms,
                                     boundary, force_units, neighbors, n_threads)
    n_atoms = length(coords)
    @inbounds if n_threads > 1
        fs_chunks = [zero(fs) for _ in 1:n_threads]

        if length(pairwise_inters_nonl) > 0
            Threads.@threads for chunk_i in 1:n_threads
                for i in chunk_i:n_threads:n_atoms
                    for j in (i + 1):n_atoms
                        dr = vector(coords[i], coords[j], boundary)
                        f = force(pairwise_inters_nonl[1], dr, atoms[i], atoms[j], force_units, false,
                                  coords[i], coords[j], boundary, velocities[i], velocities[j], 0)
                        for inter in pairwise_inters_nonl[2:end]
                            f += force(inter, dr, atoms[i], atoms[j], force_units, false,
                                       coords[i], coords[j], boundary, velocities[i], velocities[j], 0)
                        end
                        check_force_units(f, force_units)
                        f_ustrip = ustrip.(f)
                        fs_chunks[chunk_i][i] -= f_ustrip
                        fs_chunks[chunk_i][j] += f_ustrip
                    end
                end
            end
        end

        if length(pairwise_inters_nl) > 0
            if isnothing(neighbors)
                error("an interaction uses the neighbor list but neighbors is nothing")
            end
            Threads.@threads for chunk_i in 1:n_threads
                for ni in chunk_i:n_threads:length(neighbors)
                    i, j, special = neighbors[ni]
                    dr = vector(coords[i], coords[j], boundary)
                    f = force(pairwise_inters_nl[1], dr, atoms[i], atoms[j], force_units, special,
                              coords[i], coords[j], boundary, velocities[i], velocities[j], 0)
                    for inter in pairwise_inters_nl[2:end]
                        f += force(inter, dr, atoms[i], atoms[j], force_units, special,
                                   coords[i], coords[j], boundary, velocities[i], velocities[j], 0)
                    end
                    check_force_units(f, force_units)
                    f_ustrip = ustrip.(f)
                    fs_chunks[chunk_i][i] -= f_ustrip
                    fs_chunks[chunk_i][j] += f_ustrip
                end
            end
        end

        fs .+= sum(fs_chunks)
    else
        if length(pairwise_inters_nonl) > 0
            for i in 1:n_atoms
                for j in (i + 1):n_atoms
                    dr = vector(coords[i], coords[j], boundary)
                    f = force(pairwise_inters_nonl[1], dr, atoms[i], atoms[j], force_units, false,
                              coords[i], coords[j], boundary, velocities[i], velocities[j], 0)
                    for inter in pairwise_inters_nonl[2:end]
                        f += force(inter, dr, atoms[i], atoms[j], force_units, false,
                                   coords[i], coords[j], boundary, velocities[i], velocities[j], 0)
                    end
                    check_force_units(f, force_units)
                    f_ustrip = ustrip.(f)
                    fs[i] -= f_ustrip
                    fs[j] += f_ustrip
                end
            end
        end

        if length(pairwise_inters_nl) > 0
            if isnothing(neighbors)
                error("an interaction uses the neighbor list but neighbors is nothing")
            end
            for ni in eachindex(neighbors)
                i, j, special = neighbors[ni]
                dr = vector(coords[i], coords[j], boundary)
                f = force(pairwise_inters_nl[1], dr, atoms[i], atoms[j], force_units, special,
                          coords[i], coords[j], boundary, velocities[i], velocities[j], 0)
                for inter in pairwise_inters_nl[2:end]
                    f += force(inter, dr, atoms[i], atoms[j], force_units, special,
                               coords[i], coords[j], boundary, velocities[i], velocities[j], 0)
                end
                check_force_units(f, force_units)
                f_ustrip = ustrip.(f)
                fs[i] -= f_ustrip
                fs[j] += f_ustrip
            end
        end
    end

    @inbounds for inter_list in sils_1_atoms
        for (i, inter) in zip(inter_list.is, inter_list.inters)
            sf = force(inter, coords[i], boundary)
            check_force_units(sf.f1, force_units)
            fs[i] += ustrip.(sf.f1)
        end
    end

    @inbounds for inter_list in sils_2_atoms
        for (i, j, inter) in zip(inter_list.is, inter_list.js, inter_list.inters)
            sf = force(inter, coords[i], coords[j], boundary)
            check_force_units(sf.f1, force_units)
            check_force_units(sf.f2, force_units)
            fs[i] += ustrip.(sf.f1)
            fs[j] += ustrip.(sf.f2)
        end
    end

    @inbounds for inter_list in sils_3_atoms
        for (i, j, k, inter) in zip(inter_list.is, inter_list.js, inter_list.ks, inter_list.inters)
            sf = force(inter, coords[i], coords[j], coords[k], boundary)
            check_force_units(sf.f1, force_units)
            check_force_units(sf.f2, force_units)
            check_force_units(sf.f3, force_units)
            fs[i] += ustrip.(sf.f1)
            fs[j] += ustrip.(sf.f2)
            fs[k] += ustrip.(sf.f3)
        end
    end

    @inbounds for inter_list in sils_4_atoms
        for (i, j, k, l, inter) in zip(inter_list.is, inter_list.js, inter_list.ks, inter_list.ls,
                                       inter_list.inters)
            sf = force(inter, coords[i], coords[j], coords[k], coords[l], boundary)
            check_force_units(sf.f1, force_units)
            check_force_units(sf.f2, force_units)
            check_force_units(sf.f3, force_units)
            check_force_units(sf.f4, force_units)
            fs[i] += ustrip.(sf.f1)
            fs[j] += ustrip.(sf.f2)
            fs[k] += ustrip.(sf.f3)
            fs[l] += ustrip.(sf.f4)
        end
    end

    return nothing
end

function forces(sys::System{D, true, T}, neighbors;
                n_threads::Integer=Threads.nthreads()) where {D, T}
    n_atoms = length(sys)
    val_ft = Val(T)
    fs_mat = CUDA.zeros(T, D, n_atoms)

    pairwise_inters_nonl = filter(!use_neighbors, values(sys.pairwise_inters))
    if length(pairwise_inters_nonl) > 0
        nbs = NoNeighborList(n_atoms)
        fs_mat += pairwise_force_gpu(sys.coords, sys.velocities, sys.atoms, sys.boundary, pairwise_inters_nonl,
                                     nbs, sys.force_units, val_ft)
    end

    pairwise_inters_nl = filter(use_neighbors, values(sys.pairwise_inters))
    if length(pairwise_inters_nl) > 0
        if isnothing(neighbors)
            error("an interaction uses the neighbor list but neighbors is nothing")
        end
        if length(neighbors) > 0
            nbs = @view neighbors.list[1:neighbors.n]
            fs_mat += pairwise_force_gpu(sys.coords, sys.velocities, sys.atoms, sys.boundary, pairwise_inters_nl,
                                         nbs, sys.force_units, val_ft)
        end
    end

    for inter_list in values(sys.specific_inter_lists)
        fs_mat += specific_force_gpu(inter_list, sys.coords, sys.boundary, sys.force_units, val_ft)
    end

    fs = reinterpret(SVector{D, T}, vec(fs_mat))

    for inter in values(sys.general_inters)
        fs_gen = AtomsCalculators.forces(sys, inter; neighbors=neighbors, n_threads=n_threads)
        check_force_units(unit(eltype(eltype(fs_gen))), sys.force_units)
        fs += ustrip_vec.(fs_gen)
    end

    return fs * sys.force_units
end
