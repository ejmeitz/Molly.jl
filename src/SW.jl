#const SW_Silicon = (SiSiSi = SW_Params(...))
#const SW_GaN = (NNN = SW_Params(...),
#                GaNN = SW_Params(...),
#                ....
#)

#* TODO: Ethan, Have SW split into Pair and Threebody potentials automatically
#* since the force kernels only work for pair and then three body

# All the input parameters are given a dataframe with first column defining atoms that are interacting "A-B" 
# Cross interaction will be generated based on some equivalent rules
df = DataFrame(interaction = ["Si-Si","Si-C","Si-O","C-C","C-O","O-O"],
                epsilon = [2.5,2.5,2.5,2.5,2.5,2.5],
                sigma = [2.5,2.5,2.5,2.5,2.5,2.5],
                a = [2.5,2.5,2.5,2.5,2.5,2.5],
                lambda = [2.5,2.5,2.5,2.5,2.5,2.5],
                gamma = [2.5,2.5,2.5,2.5,2.5,2.5],
                cosTheta = [2.5,2.5,2.5,2.5,2.5,2.5],
                A = [2.5,2.5,2.5,2.5,2.5,2.5],
                B`` = [2.5,2.5,2.5,2.5,2.5,2.5],
                p = [2.5,2.5,2.5,2.5,2.5,2.5],
                q = [2.5,2.5,2.5,2.5,2.5,2.5],
                )
function SW_Params(df::DataFrame)
    # check if all the entries are present
    # check if the entries are in the correct format
    # check if the entries are in the correct order
    #= [join(sort([df[i,:atom1],df[i,:atom2]]),"-") for i in 1:size(df,1)] =#
    interact = df[!,:interaction] 
    atoms = unique(reduce(vcat, split.(interact,"-")))
    vec(collect(Iterators.product(Iterators.repeated(atoms,3)...)))

    if len(atoms) > 3
        throw(ArgumentError("Stillinger-Weber supports at most 3 unique species, got $(len(atoms))"))
    end
    


    # Some code to generate the cross interaction

    return df
end