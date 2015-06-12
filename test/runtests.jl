using KISSTraits
using Base.Test

typealias False Val{false}
typealias True Val{true}

# definition & adding
@traitdef Tr1{X}
@test istrait(Tr1{Int})==False
@traitadd Tr1{Integer}
@test istrait(Tr1{Int})==True
@test istrait(Tr1{Bool})==True
@test istrait(Tr1{String})==False

@traitdef Tr2{X,Y}
@test istrait(Tr2{Int,FloatingPoint})==False
@traitadd Tr2{Integer, Float64}
@test istrait(Tr2{Int, Float64})==True
@test istrait(Tr2{Int, Float32})==False

# trait functions
@traitfn f{X; Tr1{X}}(x::X) = 1  # def 1
@traitfn f{X; !Tr1{X}}(x::X) = 2
@test f(5)==1
@test f(5.)==2

@traitfn f{X,Y; Tr2{X,Y}}(x::X,y::Y,z) = 1
@test f(5,5., "a")==1
@test_throws MethodError f(5,5, "a")==2
@traitfn f{X,Y; !Tr2{X,Y}}(x::X,y::Y,z) = 2
@test f(5,5, "a")==2

# TODO:
# this will overwrite the definition above
@traitfn f{X; !Tr2{X,X}}(x::X) = 10
@test f(5)==10
@test f(5.)==10
@traitadd Tr2{Integer, Integer}
@traitfn f{X; !Tr2{X,X}}(x::X) = 10 # update cache
@test f(5)==1 # this now goes to (def 1)
@traitfn f{X; Tr2{X,X}}(x::X) = 100
@test f(5)==100
@test f(5.)==10
