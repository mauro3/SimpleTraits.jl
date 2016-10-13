using SimpleTraits
using Base.Test

trait = SimpleTraits.trait

# @test_throws MethodError trait(4)
@test_throws ErrorException istrait(4)

# definition & adding
@traitdef Tr1{X}
@test trait(Tr1{Int})==Not{Tr1{Int}}
@test !istrait(Tr1{Int})
@traitimpl Tr1{Integer}
@test trait(Tr1{Int})==Tr1{Int}
@test istrait(Tr1{Int})
@test trait(Tr1{Bool})==Tr1{Bool}
@test trait(Tr1{AbstractString})==Not{Tr1{AbstractString}}
@test !istrait(Tr1{AbstractString})

# Logic.  trait(Tr) returns the same trait Tr if it is fulfilled and
# Not{Tr} otherwise.  This is a bit confusing.
@test trait(Tr1{AbstractString})==Not{Tr1{AbstractString}}
@test istrait(Tr1{AbstractString})==false
@test trait(Not{Tr1{AbstractString}})==Not{Tr1{AbstractString}}
@test istrait(Not{Tr1{AbstractString}})==true
@test trait(Not{Not{Tr1{AbstractString}}})==Not{Tr1{AbstractString}}
@test istrait(Not{Not{Tr1{AbstractString}}})==false
@test trait(Not{Not{Not{Tr1{AbstractString}}}})==Not{Tr1{AbstractString}}
@test istrait(Not{Not{Not{Tr1{AbstractString}}}})==true

@test trait(Not{Tr1{Integer}})==Tr1{Integer}
@test istrait(Not{Tr1{Integer}})==false
@test trait(Not{Not{Tr1{Integer}}})==Tr1{Integer}
@test istrait(Not{Not{Tr1{Integer}}})==true
@test trait(Not{Not{Not{Tr1{Integer}}}})==Tr1{Integer}
@test istrait(Not{Not{Not{Tr1{Integer}}}})==false


@traitdef Tr2{X,Y}
@test trait(Tr2{Int,AbstractFloat})==Not{Tr2{Int,AbstractFloat}}
@traitimpl Tr2{Integer, Float64}
@test trait(Tr2{Int, Float64})==Tr2{Int, Float64}
@test trait(Tr2{Int, Float32})==Not{Tr2{Int, Float32}}

# issue 9
abstract A9
type B9<:A9 end
type C9<:A9 end
@traitdef Tr9{X}
@traitimpl Tr9{A9}
@traitimpl Not{Tr9{B9}}
@traitimpl !Tr9{C9}
@test istrait(Tr9{A9})==true
@test istrait(Tr9{B9})==false
@test istrait(Tr9{C9})==false

#################
# Trait functions
#################
# functions with `t` postfix are the same as previous ones but using Traitor syntax
@traitfn f{X; Tr1{X}}(x::X) = 1  # def 1
@traitfn f{X; !Tr1{X}}(x::X) = 2
@test f(5)==1
@test f(5.)==2

@traitfn ft(x::::Tr1) = 1  # def 1
@traitfn ft(x::::(!Tr1)) = 2
@test ft(5)==1
@test ft(5.)==2


@traitfn f{X,Y; Tr2{X,Y}}(x::X,y::Y,z) = 1
@test f(5,5., "a")==1
@test_throws MethodError f(5,5, "a")==2
@traitfn f{X,Y; !Tr2{X,Y}}(x::X,y::Y,z) = 2
@test f(5,5, "a")==2
# Note, two argument traits have no Traitor style syntax

# This will overwrite the definition def1 above

VERSION>=v"0.5" && println("\nOne warning expected:")
@traitfn f{X; !Tr2{X,X}}(x::X) = 10
@traitfn f{X; Tr2{X,X}}(x::X) = 100
@test f(5)==10
@test f(5.)==10
@traitimpl Tr2{Integer, Integer}
@test f(5.)==10
@test !(f(5)==100)
# needed to update method cache:
VERSION>=v"0.5" && println("\nTwo warnings expected:")
@traitfn f{X; Tr2{X,X}}(x::X) = 100
println("")
@test f(5)==100
@test f(5.)==10

# VarArg
@traitfn vara{X; Tr1{X}}(x::X, y...) = y
@traitfn vara{X; !Tr1{X}}(x::X, y...) = x
@test vara(5, 7, 8)==(7,8)
@test vara(5.0, 7, 8)==5.0
@traitfn vara2{X; Tr1{X}}(x::X...) = x
@test vara2(5, 7, 8)==(5, 7, 8)
@test_throws MethodError vara2(5, 7, 8.0)

@traitfn vara3{X; Tr1{X}}(::X...) = X
@test vara3(5, 7, 8)==Int
@test_throws MethodError vara3(5, 7, 8.0)


@traitfn varat(x::::Tr1, y...) = y
@traitfn varat(x::::(!Tr1), y...) = x
@test varat(5, 7, 8)==(7,8)
@test varat(5.0, 7, 8)==5.0
@traitfn vara2t(x::::Tr1...) = x
@test vara2t(5, 7, 8)==(5, 7, 8)
@test_throws MethodError vara2t(5, 7, 8.0)

@traitfn vara3t{X}(::X::Tr1...) = X
@test vara3t(5, 7, 8)==Int
@test_throws MethodError vara3t(5, 7, 8.0)


# with macro
@traitfn @inbounds gg{X; Tr1{X}}(x::X) = x
@test gg(5)==5
@traitfn @generated ggg{X; Tr1{X}}(x::X) = X<:AbstractArray ? :(x+1) : :(x)
@test ggg(5)==5
@traitimpl Tr1{AbstractArray}
@test ggg([5])==[6]

@traitfn @inbounds ggt(x::::Tr1) = x
@test ggt(5)==5
@traitfn @generated gggt{X}(x::X::Tr1) = X<:AbstractArray ? :(x+1) : :(x)
@test gggt(5)==5
@test gggt([5])==[6]


# traitfn with Type
@traitfn ggt{X; Tr1{X}}(::Type{X}, y) = (X,y)
@test ggt(Array, 5)==(Array, 5)
# no equivalent with Traitor syntax

# traitfn with ::X
@traitfn gg27{X; Tr1{X}}(::X) = X
@test gg27([1])==Array{Int,1}

@traitfn gg27t{X}(::X::Tr1) = X
@test gg27t([1])==Array{Int,1}

##
@traitfn f11{T<:Number;  Tr1{Dict{T}}}(x::Dict{T}) = 1
@traitfn f11{T<:Number; !Tr1{Dict{T}}}(x::Dict{T}) = 2
@traitimpl Tr1{Dict{Int}}
@test f11(Dict(1=>1))==1
@test f11(Dict(5.5=>1))==2

@traitfn f11t{T<:Number}(x::Dict{T}::Tr1) = 1
@traitfn f11t{T<:Number}(x::Dict{T}::(!Tr1)) = 2
@test f11t(Dict(1=>1))==1
@test f11t(Dict(5.5=>1))==2

##
@traitfn f12t(::::Tr1) = 1
@traitfn f12t(::::(!Tr1)) = 2
@test f12t(1)==1
@test f12t(5.5)==2

######
# Other tests
#####
include("base-traits.jl")

if VERSION >= v"0.5.0-dev"
    include("backtraces.jl")
end
