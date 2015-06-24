module SimpleTraits

# This is basically just adding a few convenience functions & macros
# around Holy Traits.

export Trait, istrait, @traitdef, @traitadd, @traitfn, Not

# All traits are concrete subtypes of this trait.  SUPER is not used
# but present to be compatible with Traits.jl.
## @doc """
## `abstract Trait{SUPER}`

## All traits are direct decedents of abstract type Trait.  The type parameter
## SUPER of Trait is needed to specify super-traits (a tuple).""" ->
abstract Trait{SUPER}
# a concrete Trait will look like
## immutable Tr1{X,Y} <: Trait end
# where X and Y are the types involved in the trait.

# The set of all types not belonging to a trait is encoded by, e.g.
# Not{Tr1{X,Y}}
immutable Not{T<:Trait} <: Trait end
# stips an even number of Nots off: Not{Not{T}}->T
stripNot{T<:Trait}(Tr::Type{T}) = Tr
function stripNot{T<:Not}(Tr::Type{T})
    Tr = T.parameters[1]
    Tr<:Trait || error("`Not` cannot be used without a `Trait` as parameter")
    return Tr<:Not ? Tr.parameters[1] : T
end

# Transforms a type encoding a trait into itself if the trait is
# fulfilled, or into Not{itself}.  It is used to define whether a
# trait is implemented for a set of types or not.  Trait-dispatch then
# uses this.  Default for any type is that it is not fulfilled:
trait{T<:Trait}(::Type{T}) = Not{T}
function trait{T<:Not}(::Type{T})
    Tr = stripNot(T)
    Tr = Tr<:Not ? Tr.parameters[1] : Tr # strip also last Not
    return trait(Tr)==Tr ? Tr : Not{Tr}
end

## Implement trait for specific types:
#   trait(::Type{Tr1{Int,Float64}}) = Tr1{Int,Float64}
# or
#   trait{I<:Integer,F<:FloatingPoint}(::Type{Tr1{I,F}}) = Tr1{I,F}
#
# Note invariance, this does probably not the right thing:
#   trait(::Type{Tr1{Integer,FloatingPoint}}) = Tr1{Integer, FloatingPoint}

# Function istrait checks whether a trait is fulfilled by a specific
# set of types (builds on `trait`):
## istrait(Tr1{Int,Float64}) => return true or false
istrait(::Any) = error("Argument is not a Trait.")
istrait{T<:Trait}(tr::Type{T}) = trait(tr)==stripNot(tr) ? true : false # Problem, this can run into issue #265
                                                                        # thus redefine when traits are defined

# Defining a trait
# @traitdef Tr1{X,Y}
macro traitdef(tr)
    :(immutable $(esc(tr)) <: Trait end)
end

# Adding types to a trait
# @traitadd Tr1{Int,Float64}
macro traitadd(tr)
    # makes
    # trait{X1<:Int,X2<:Float64}(::Type{Tr1{X1,X2}}) = Tr1{X1,X2}
    typs = tr.args[2:end]
    trname = tr.args[1]
    curly = Any[]
    paras = Any[]
    for (ty,v) in zip(typs, GenerateTypeVars{:upcase}())
        push!(curly, Expr(:(<:), v, ty))  #:($v<:$ty)
        push!(paras, v)
    end
    arg = :(::Type{$trname{$(paras...)}})
    fnhead = :(SimpleTraits.trait{$(curly...)}($arg))
    isfnhead = :(SimpleTraits.istrait{$(curly...)}($arg))
    esc(quote
        $fnhead = $trname{$(paras...)}
        $isfnhead = true # Add the istrait definition as otherwise
                         # method-caching can be an issue.
    end)
end

# Defining a function dispatching on the trait (or not)
# @traitfn f{X,Y;  Tr1{X,Y}}(x::X,y::Y) = ...
# @traitfn f{X,Y; !Tr1{X,Y}}(x::X,y::Y) = ... # which is just sugar for:
# @traitfn f{X,Y; Not{Tr1{X,Y}}}(x::X,y::Y) = ...
function traitfn(tfn)
    # Need
    # f{X,Y}(x::X,Y::Y) = f(trait(Tr1{X,Y}), x, y)
    # f(::False, x, y)= ...
    fhead = tfn.args[1]
    fbody = tfn.args[2]
    fname = fhead.args[1].args[1]
    args = fhead.args[2:end]
    typs = fhead.args[1].args[3:end]
    trait = fhead.args[1].args[2].args[1]
    if isnegated(trait)
        trait = trait.args[2]
        val = :(::Type{SimpleTraits.Not{$trait}})
    else
        val = :(::Type{$trait})
    end
    quote
        $fname{$(typs...)}($(args...)) = $fname(SimpleTraits.trait($trait), $(striparg(args)...))
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

####
# Extras
####

include("base-traits.jl")

end # module
