using SimpleTraits.BaseTraits
using Compat: view

@test istrait(IsAnything{Any})
@test istrait(IsAnything{Union{}})
@test istrait(IsAnything{Int})

@test !istrait(IsNothing{Any})
@test !istrait(IsNothing{Union{}})
@test !istrait(IsNothing{Int})

@test istrait(IsBits{Int})
@test !istrait(IsBits{Vector{Int}})

@test istrait(IsImmutable{Float64})
@test !istrait(IsImmutable{Vector{Int}})

@test istrait(IsCallable{Function})

a = collect(1:5)
b = view(a, 2:3)
c = view(a, 1:2:5)
@test istrait(IsContiguous{typeof(b)})
@test !istrait(IsContiguous{typeof(c)})

@test istrait(IsIndexLinear{Vector})
@test !istrait(IsIndexLinear{AbstractArray})

if VERSION < v"0.5.0-dev"
    # this give deprecation warning in Julia 0.5
    @test istrait(IsCallable{Base.AddFun})
end

@test istrait(IsIterable{Array})
@test !istrait(IsIterable{Cmd})
