using SimpleTraits
using Base.Test

const trait = SimpleTraits.trait

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
abstract type A9 end
struct B9<:A9 end
struct C9<:A9 end
@traitdef Tr9{X}
@traitimpl Tr9{A9}
@traitimpl Not{Tr9{B9}}
@traitimpl !Tr9{C9}
@test istrait(Tr9{A9})==true
@test istrait(Tr9{B9})==false
@test istrait(Tr9{C9})==false

# issue #15 is tested through the base-traits.jl tests.

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

@traitfn f{X; !Tr2{X,X}}(x::X) = 10
@traitfn f{X; Tr2{X,X}}(x::X) = 100
@test f(5)==10
@test f(5.)==10
@traitimpl Tr2{Integer, Integer}
@test f(5.)==10
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

# kwargs (issue 27)
@traitfn kwfn1(x::::Tr1; k=1) = x+k
@traitfn kwfn1(x::::(!Tr1); k=2) = x-k
@test kwfn1(5)==6
@test kwfn1(5.0)==3.0
@test kwfn1(5,k=2)==7
@test kwfn1(5.0,k=3)==2.0

@traitfn kwfn2(x::::Tr1, y...; k=1) = x+y[1]+k
@traitfn kwfn2(x::::(!Tr1), y...; k::Int=2) = x+y[1]-k
@test kwfn2(5,5)==11
@test kwfn2(5.0,5)==8.0
@test kwfn2(5,5,k=2)==12
@test kwfn2(5.0,5,k=3)==7.0
@test_throws TypeError kwfn2(5.0,5,k="sadf")

@traitfn kwfn3(x::::Tr1, y...; kws...) = x+y[1]+length(kws)
@traitfn kwfn3(x::::(!Tr1), y...; kws...) = x+y[1]-length(kws)
@test kwfn3(5,5)==10
@test kwfn3(5.0,5)==10
@test kwfn3(5,5,k=2)==11
@test kwfn3(5.0,5,k=3)==9
@test kwfn3(5.0,5,k=3,kk=9)==8

@traitfn kwfn4(x::::Tr1, y...; kws...) = x+y[1]+length(kws)
@test_throws ErrorException @traitfn kwfn4(x::::(!Tr1), y...) = x+y[1]-length(kws)
@traitfn kwfn5(x::::Tr1, y...) = x+y[1]+length(kws)
@test_throws ErrorException @traitfn kwfn5(x::::(!Tr1), y...; k=1) = x+y[1]-length(kws)

# Default args, issue #32
####
@traitfn defargs1(x::::Tr1, y=2) = x+y
@traitfn defargs1(x::::(!Tr1), y=2) = x-y
@test defargs1(1,3)==4
@test defargs1(1)==3
@test defargs1(1.0,4)==-3
@test defargs1(1.0)==-1

@traitfn defargs2(x::::Tr1, y=2) = x+y
@test_throws ErrorException @traitfn defargs2(x::::(!Tr1), y=3) = x-y
@traitfn defargs3(x::::Tr1, y=2) = x+y
@test_throws ErrorException @traitfn defargs3(x::::(!Tr1), y) = x-y


@traitfn defargs4(x::::Tr1, y=2; k=1) = x+y+k
@traitfn defargs4(x::::(!Tr1), y=2; k=2) = x-y+k
@test defargs4(1,3)==5
@test defargs4(1)==4
@test defargs4(1.0,4)==-1
@test defargs4(1.0)==1
@test defargs4(1.0, k=10)==9

@traitfn defargs5(x::::Tr1, y=2, z...; k=1) = (x+y+k,z)
@traitfn defargs5(x::::(!Tr1), y=2, z...; k=2) = (x-y+k,z)
@test defargs5(1,3)==(5,())
@test defargs5(1,3,4,5)==(5,(4,5))
@test defargs5(1)==(4,())
@test defargs5(1.0,4)==(-1,())
@test defargs5(1.0,k=10)==(9,())

@traitfn defargs6{X;  Tr1{X}}(x::X=1, y=2) = x+y
@traitfn defargs6{X; !Tr1{X}}(x::X=1, y=2) = x-y
@test defargs6()==3
@test defargs6(1,3)==4
@test defargs6(1)==3
@test defargs6(1.0,4)==-3
@test defargs6(1.0)==-1
# above does not work with Traitor syntax
@test_broken SimpleTraits.traitfn(:(defargs6a(x::::Tr1=1, y=2) = x+y))


# traitfn with macro
@traitfn @inbounds gg{X; Tr1{X}}(x::X) = x
@test gg(5)==5
@traitfn @generated ggg{X; Tr1{X}}(x::X) = X<:AbstractArray ? :(x+x) : :(x)
@test ggg(5)==5
@traitimpl Tr1{AbstractArray}
@test ggg([5])==[10]

@traitfn @inbounds ggt(x::::Tr1) = x
@test ggt(5)==5
@traitfn @generated gggt{X}(x::X::Tr1) = X<:AbstractArray ? :(x+x) : :(x)
@test gggt(5)==5
@test gggt([5])==[10]


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


###
# @traitimpl Tr{X} <- istr(X)
@traitdef TrArrow1{X}
isarrow(X) = eltype(X)<:Integer ? true : false
@traitimpl TrArrow1{X} <- isarrow(X)
@test istrait(TrArrow1{Vector{Int}})
@test !istrait(TrArrow1{Vector{Float64}})

@traitdef TrArrow2{X}
@traitimpl Not{TrArrow2{X}} <- isarrow(X)
@test !istrait(TrArrow2{Vector{Int}})
@test istrait(TrArrow2{Vector{Float64}})


######
# Other tests
#####
include("base-traits.jl")
include("base-traits-inference.jl")
include("backtraces.jl")
