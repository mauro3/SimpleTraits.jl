using SimpleTraits
using Base.Test

trait = SimpleTraits.trait
Inter = SimpleTraits.TraitIntersection

immutable A end
immutable B end

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
@traitimpl Tr2{Integer, Integer}
@test f(5.)==10
@test !(f(5)==100)
# need to update method cache:
@traitfn f{X; Tr2{X,X}}(x::X) = 100
@test f(5)==100
@test f(5.)==10

# VarArg
@traitfn g{X; Tr1{X}}(x::X, y...) = y
@test g(5, 7, 8)==((7,8),)
# @test g(5.0, 7, 8)==((7,8),) # hangs because of https://github.com/JuliaLang/julia/issues/13183

# with macro
@traitfn @inbounds gg{X; Tr1{X}}(x::X) = x
@test gg(5)==5
@traitfn @generated ggg{X; Tr1{X}}(x::X) = X<:AbstractArray ? :(x+1) : :(x)
@test ggg(5)==5
@traitimpl Tr1{AbstractArray}
@test ggg([5])==[6]

# traitfn with Type
@traitfn ggt{X; Tr1{X}}(::Type{X}, y) = (X,y)
@test ggt(Array, 5)==(Array, 5)

# traitfn with ::X
@traitfn gg27{X; Tr1{X}}(::X) = X
@test gg27([1])==Array{Int,1}


# Tuple traits
# typealias STr3{X,Y} Inter{Tuple{Tr1{X}, Tr2{X,Y}}}
# @test istrait(STr3{Int,Float64})
# @traitfn f54{X, Y;  STr3{X,Y}}(x::X, y::Y) = 1
# @traitfn f54{X, Y; !STr3{X,Y}}(x::X, y::Y) = 2
# @test f54(4,5.0)==1
# @test f54("asdf","asdf")==2

# @test_throws ErrorException @traitimpl STr3{A, Float64}
# @traitimpl Tr1{A}
# @traitimpl Tr2{A, Float64}
# @test f54(A(),5.0)==1

# # nested subtraits
# @traitdef Tr3{X}
# @traitimpl Tr3{A}
# typealias STr4{X,Y} Inter{Tuple{STr3{X,Y}, Tr3{X}}}
# @test istrait(STr4{A, Float64})
# @test !istrait(STr4{Float64, A})
# # use traitdef syntax:
# @traitdef STr44{X,Y} <: STr3{X,Y}, Tr3{X}
# @test STr44===STr4
# @test STr44{A,Int}===STr4{A,Int}

## several traits
@traitdef TT1{X}
@traitimpl TT1{A}
@traitdef TT2{Y}
@traitimpl TT2{B}
# this gives combinations:
@test trait(Inter{Tuple{TT1{A},TT2{B}}})==Inter{Tuple{    TT1{A} ,     TT2{B} }}
@test trait(Inter{Tuple{TT1{A},TT2{A}}})==Inter{Tuple{    TT1{A} , Not{TT2{A} }}}
@test trait(Inter{Tuple{TT1{B},TT2{B}}})==Inter{Tuple{Not{TT1{B}},     TT2{B} }}
@test trait(Inter{Tuple{TT1{B},TT2{A}}})==Inter{Tuple{Not{TT1{B}}, Not{TT2{A} }}}




# @traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y) = 1
# @traitfn f55{X, Y; !TT1{X},  TT2{Y}}(x::X, y::Y) = 2
# @traitfn f55{X, Y; !TT1{X}, !TT2{Y}}(x::X, y::Y) = 3
# @traitfn f55{X, Y;  TT1{X}, !TT2{Y}}(x::X, y::Y) = 4

# @test f55(A(),B())==1
# @test f55(B(),B())==2
# @test f55(B(),A())==3
# @test f55(A(),A())==4

######
# Other tests
#####
include("base-traits.jl")
