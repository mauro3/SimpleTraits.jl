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

if VERSION>v"0.4-" # use @generated functions
    a = collect(1:5)
    b = view(a, 2:3)
    c = view(a, 1:2:5)
    @test istrait(IsContiguous{typeof(b)})
    @test !istrait(IsContiguous{typeof(c)})

    @test istrait(IsFastLinearIndex{Vector})
    @test !istrait(IsFastLinearIndex{AbstractArray})

    if VERSION < v"0.5.0-dev"
        @test istrait(IsCallable{Base.AddFun})
    end
end
