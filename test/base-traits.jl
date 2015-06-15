using SimpleTraits.BaseTraits

@test istrait(IsBits{Int})
@test !istrait(IsBits{Vector{Int}})

@test istrait(IsImmutable{Float64})
@test !istrait(IsImmutable{Vector{Int}})


if VERSION>v"0.4-" # use @generated functions
    @test istrait(IsContiguous{SubArray{Int64,1,Array{Int64,1},Tuple{UnitRange{Int64}},1}})
    @test !istrait(IsContiguous{SubArray{Int64,1,Array{Int64,1},Tuple{StepRange{Int64,Int64}},1}})

    @test istrait(IsFastLinearIndex{Vector})
    @test !istrait(IsFastLinearIndex{AbstractArray})
end


