module KISSTraits

# This is basically just adding a few convenience functions & macros
# around Holy Traits.

export Trait, istrait, @traitdef, @traitadd, @traitfn
# All traits are concrete subtypes of this trait.  SUPER is not used
# but present to be compatible with Traits.jl.
abstract Trait{SUPER}
# a concrete Trait will look like
## immutable Tr1{X,Y} <: Trait end
# where X and Y are the types involved in the trait.

if VERSION<v"0.4-"
    export Val
    immutable Val{T} end
end


typealias False Val{false}
typealias True Val{true}

# Function istrait is used to check whether a trait is fulfilled by a
# specific set of types:
## istrait(Tr1{Int,Float64}) => return True or False
#
# For Julia to be able to eliminate the call to istrait, it needs to
# be a constant function and to return a type and not a value.

istrait(::Any) = error("Only call with a subtype of Trait as argument.")
# default to false
istrait{T<:Trait}(::Type{T}) = False
## Define istrait for your traits:
# istrait(::Type{Tr1{Int,Float64}}) = True
#or
# istrait{I<:Integer,F<:FloatingPoint}(::Type{Tr1{I,F}}) = True


# Defining a trait
# @traitdef Tr1{X,Y}
macro traitdef(tr)
    esc(:(immutable $tr <:KISSTraits.Trait end))
end

# Adding types to a trait
# @traitadd Tr1{Int,Float64}
macro traitadd(tr)
    # makes
    # istrait{X1<:Int,X2<:Float64}(::Type{Tr1{X1,X2}})
    typs = tr.args[2:end]
    tr = tr.args[1]
    curly = Any[]
    paras = Any[]
    for (ty,v) in zip(typs, GenerateTypeVars{:upcase}())
        push!(curly, Expr(:(<:), v, ty))  #:($v<:$ty)
        push!(paras, v)
    end
    arg = :(::Type{$tr{$(paras...)}})
    fnhead = :(KISSTraits.istrait{$(curly...)}($arg))
    esc(:($fnhead = True))
end

# Defining a function dispatching on the trait (or not)
# @traitfn f{X,Y;  Tr1{X,Y}}(x::X,y::Y) = ...
# @traitfn f{X,Y; !Tr1{X,Y}}(x::X,y::Y) = ...
function traitfn(tfn)
    # Need
    # f{X,Y}(x::X,Y::Y) = f(istrait(Tr1{X,Y}), x, y)
    # f(::False, x, y)= ...
    fhead = tfn.args[1]
    fbody = tfn.args[2]
    fname = fhead.args[1].args[1]
    args = fhead.args[2:end]
    typs = fhead.args[1].args[3:end]
    trait = fhead.args[1].args[2].args[1]
    if isnegated(trait)
        val = :(::Type{KISSTraits.False})
        trait = trait.args[2]
    else
        val = :(::Type{KISSTraits.True})
    end
    quote
        $fname{$(typs...)}($(args...)) = $fname(istrait($trait), $(striparg(args)...))
        $fname{$(typs...)}($val, $(args...)) = $fbody
    end
end
macro traitfn(tfn)
    esc(traitfn(tfn))
end

######
## Helpers
######

# true if :(!(Tr{x}))
isnegated(t::Expr) = t.head==:call

# [:(x::X)] -> [:x]
striparg(args::Vector) = [striparg(a) for a in args]
striparg(a::Symbol) = a
striparg(a::Expr) = a.args[1]

# generates: X1, X2,... or x1, x2.... (just symbols not actual TypeVar)
type GenerateTypeVars{CASE}
end
Base.start(::GenerateTypeVars) = 1
Base.next(::GenerateTypeVars{:upcase}, state) = (symbol("X$state"), state+1) # X1,..
Base.next(::GenerateTypeVars{:lcase}, state) = (symbol("x$state"), state+1)  # x1,...
Base.done(::GenerateTypeVars, state) = false
             
             
end # module
