using SimpleTraits
using Base.Test

trait = SimpleTraits.trait

# @test_throws MethodError trait(4)
@test_throws ErrorException istrait(4)

# definition & adding
@traitdef Tr1{X}
@test trait(Tr1{Int})==Not{Tr1{Int}}
@test !istrait(Tr1{Int})
@traitadd Tr1{Integer}
@test trait(Tr1{Int})==Tr1{Int}
@test istrait(Tr1{Int})
@test trait(Tr1{Bool})==Tr1{Bool}
@test trait(Tr1{String})==Not{Tr1{String}}
@test !istrait(Tr1{String})

# Logic.  trait(Tr) returns the same trait Tr if it is fulfilled and
# Not{Tr} otherwise.  This is a bit confusing.
@test trait(Tr1{String})==Not{Tr1{String}}
@test istrait(Tr1{String})==false
@test trait(Not{Tr1{String}})==Not{Tr1{String}}
@test istrait(Not{Tr1{String}})==true
@test trait(Not{Not{Tr1{String}}})==Not{Tr1{String}}
@test istrait(Not{Not{Tr1{String}}})==false
@test trait(Not{Not{Not{Tr1{String}}}})==Not{Tr1{String}}
@test istrait(Not{Not{Not{Tr1{String}}}})==true

@test trait(Not{Tr1{Integer}})==Tr1{Integer}
@test istrait(Not{Tr1{Integer}})==false
@test trait(Not{Not{Tr1{Integer}}})==Tr1{Integer}
@test istrait(Not{Not{Tr1{Integer}}})==true
@test trait(Not{Not{Not{Tr1{Integer}}}})==Tr1{Integer}
@test istrait(Not{Not{Not{Tr1{Integer}}}})==false


@traitdef Tr2{X,Y}
@test trait(Tr2{Int,FloatingPoint})==Not{Tr2{Int,FloatingPoint}}
@traitadd Tr2{Integer, Float64}
@test trait(Tr2{Int, Float64})==Tr2{Int, Float64}
@test trait(Tr2{Int, Float32})==Not{Tr2{Int, Float32}}

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

# This will overwrite the definition def1 above
@traitfn f{X; !Tr2{X,X}}(x::X) = 10
@traitfn f{X; Tr2{X,X}}(x::X) = 100
@test f(5)==10
@test f(5.)==10
@traitadd Tr2{Integer, Integer}
@test f(5.)==10
@test !(f(5)==100)
# need to update method cache:
@traitfn f{X; Tr2{X,X}}(x::X) = 100
@test f(5)==100
@test f(5.)==10

######
# Other tests
#####
include("base-traits.jl")
