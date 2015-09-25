module SimpleTraits
const curmod = module_name(current_module())

# This is basically just adding a few convenience functions & macros
# around Holy Traits.

export Trait, istrait, @traitdef, @traitimpl, @traitfn, Not,
       IsAnything, IsNothing

# General trait exception
type TraitException <: Exception
    msg::AbstractString
end


# All traits are subtypes of this trait.  SUPER is not used
# but present to be compatible with Traits.jl.
## @doc """
## `abstract Trait{SUPER}`
"""
All Traits are subtypes of abstract type Trait or a Tuple of Traits.
(SUPER is not used here but in Traits.jl)
"""
abstract Trait{SUPER<:Tuple}
# a concrete Trait will look like
## immutable Tr1{X,Y} <: Trait end
# where X and Y are the types involved in the trait.
# function Base.show{T<:Trait}(io::IO, Tr::Type{T})
#     invoke(show, Tuple{IO, DataType}, io, Tr)
#     print(" (a Trait)\n")
# end

"""
TraitIntersection is used when defining a trait-method like
```
@traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y)
@traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y) = 1
@traitfn f55{X, Y; !TT1{X},  TT2{Y}}(x::X, y::Y) = 2
@traitfn f55{X, Y; !TT1{X}, !TT2{Y}}(x::X, y::Y) = 3
```
to encode the total trait `{TT1{X},  TT2{Y}}`.
"""
immutable TraitIntersection{S<:Tuple} <: Trait{S} end # https://github.com/JuliaLang/julia/issues/13297
# function Base.show{T<:Tuple}(io::IO, ti::Type{TraitIntersection{T}})
#     println(io, "TraitIntersection of:")
#     for Tr in T.parameters
#         print(io, " ")
#         if Tr<:TraitIntersection
#             show(io, Tr)
#         else
#             invoke(show, Tuple{IO, DataType}, io, Tr)
#         end
#         print(io, "\n")
#     end
# end

"""
The set of all types not belonging to a trait is encoded by wrapping
it with Not{}, e.g.  Not{Tr1{X,Y}}
"""
immutable Not{T<:Trait} <: Trait end
# Helper to strip an even number of Not{}s off: Not{Not{T}}->T
stripNot{T<:Trait}(::Type{T}) = T
stripNot{T<:Trait}(::Type{Not{T}}) = Not{T}
stripNot{T<:Trait}(::Type{Not{Not{T}}}) = stripNot(T)

"""
A trait is defined as full filled if this function is the identity
function for that trait. Otherwise it returns the trait wrapped in `Not`.

Example:
```
trait(IsBits{Int}) # returns IsBits{Int}
trait(IsBits{Array}) # returns Not{IsBits{Array}}
```

Instead of using `@traitimpl` one can define a method for `trait` to
implement a trait.  If this uses `@generated` functions it will be
in-lined away.  For example the `IsBits` trait is defined by:
```
@traitdef IsBits{X}
@generated trait{X}(::Type{IsBits{X}}) = isbits(X) ? :(IsBits{X}) : :(Not{IsBits{X}})
```
"""
trait{T<:Trait}(::Type{T}) = Not{T}
trait{T<:Trait}(::Type{Not{T}}) = trait(T)

"""
TraitIntersections use a generated method of the `trait` function to
evaluate whether a trait is fulfilled or not.  If a new type is added
to a trait it can mean that this generated function is out of sync.
Use this macro to re-initialize it. (Triggers a warning)
"""
macro reset_trait_intersections()
    out = esc(:out46785) # poor man's gensym
    TU = esc(gensym())
    quote
    @generated function SimpleTraits.trait{$TU<:Tuple}(::Type{TraitIntersection{$TU}})
        $out = Any[]
        for T in $TU.parameters
            if !(T<:Trait)
                error("Need a tuple of traits")
            end
            push!($out, trait(T))
        end
        return :(SimpleTraits.TraitIntersection{Tuple{$(out46785...)}})
    end
    end
end
@reset_trait_intersections # initialize it

## Under the hood, a trait is then implemented for specific types by
## defining:
#   trait(::Type{Tr1{Int,Float64}}) = Tr1{Int,Float64}
# or
#   trait{I<:Integer,F<:FloatingPoint}(::Type{Tr1{I,F}}) = Tr1{I,F}
#
# Note due to invariance, this does probably not the right thing:
#   trait(::Type{Tr1{Integer,FloatingPoint}}) = Tr1{Integer, FloatingPoint}

"""
This function checks whether a trait is fulfilled by a specific
set of types.
```
istrait(Tr1{Int,Float64}) => return true or false
```
"""
istrait(::Any) = error("Argument is not a Trait.")
istrait{T<:Trait}(tr::Type{T}) = trait(tr)==stripNot(tr) ? true : false # Problem, this can run into issue #265
                                                                        # thus it is redefine when traits are defined

"""
Used to define a trait.  Traits, like types, are camel cased.
Often they start with `Is` or `Has`.

Examples:
```
@traitdef IsFast{X}
@traitdef IsSlow{X,Y}
```
"""
macro traitdef(tr)
    if tr.head==:curly
        :(immutable $(esc(tr)) <: Trait end)
    elseif tr.head==:tuple
        ## Error: (I)
        return :(throw(TraitException("Sub-traiting is not supported")))
        # supert = Any[esc(tr.args[1].args[3]), map(esc, tr.args[2:end])...]
        # tr = tr.args[1].args[1]
        ## Or proper supertrait  (II)
        # :(immutable $(esc(tr)) <: Trait{Tuple{$(supert...)}} end)
        ## Or alias  (III)
        :(typealias $(esc(tr)) TraitIntersection{Tuple{$(supert...)}})
    else
        throw(TraitException(
        "Either define trait as `@traitdef Tr{...}` or as subtrait of at least two supertraits `@traitdef Tr{...} <: Tr1, Tr2`"))
    end
end

"""
Used to add a type or type-tuple to a trait.  By default a type does
not belong to a trait.

Example:
```
@traitdef IsFast{X}
@traitimpl IsFast{Array{Int,1}}
```
"""
macro traitimpl(tr)
    # makes
    # trait{X1<:Int,X2<:Float64}(::Type{Tr1{X1,X2}}) = Tr1{X1,X2}
    typs = tr.args[2:end]
    trname = esc(tr.args[1])
    curly = Any[]
    paras = Any[]
    for (ty,v) in zip(typs, GenerateTypeVars{:upcase}())
        push!(curly, Expr(:(<:), esc(v), esc(ty)))  #:($v<:$ty)
        push!(paras, esc(v))
    end
    arg = :(::Type{$trname{$(paras...)}})
    fnhead = :($curmod.trait{$(curly...)}($arg))
    isfnhead = :($curmod.istrait{$(curly...)}($arg))
    quote
        $trname <: TraitIntersection && error("Cannot use @traitimpl with TraitIntersection: implement each super-trait by hand.")
        $fnhead = $trname{$(paras...)}
        $isfnhead = true # Add the istrait definition as otherwise
                         # method-caching can be an issue.
    end
end

# Defining a function dispatching on the trait (or not)
# @traitfn f{X,Y;  Tr1{X,Y}}(x::X,y::Y) = ...
# @traitfn f{X,Y; !Tr1{X,Y}}(x::X,y::Y) = ... # which is just sugar for:
# @traitfn f{X,Y; Not{Tr1{X,Y}}}(x::X,y::Y) = ...
function traitfn(tfn)
    # Need
    # f{X,Y}(x::X,Y::Y) = f(trait(Tr1{X,Y}), x, y)
    # f(::False, x, y)= ...
    if tfn.head==:macrocall
        hasmac = true
        mac = tfn.args[1]
        tfn = tfn.args[2]
    else
        hasmac = false
    end
    # see whether we're initializing the function or not:
    if tfn.head==:call
        init = true
        # add a dummy body
        tfn = :($tfn=begin 1 end)
    elseif tfn.head==:function || tfn.head==:(=)
        init = false
    else
        error("Not recognized: $tfn")
    end

    fhead = tfn.args[1]
    fname = fhead.args[1].args[1]
    args = insertdummy(fhead.args[2:end])
    tpara = fhead.args[1].args[3:end]
    # the trait dispatch wrapper
    if isa(fhead.args[1].args[2], Symbol)
        error("There are no trait-constraints, e.g. f{X; Tr{X}}(...)")
    end
    traits = fhead.args[1].args[2].args[1:end]
    trait_args = [isnegated(t) ? :($curmod.Not{$(t.args[2])}) : t for t in traits]
    trait_args = length(trait_args)==1 ? trait_args[1] : :($curmod.TraitIntersection{Tuple{$(trait_args...)}})
    # TODO: add test to throw on @traitfn f56{X,Y; !(T4{X,Y}, T{X})}(x::X, y::Y)

    trait_args_noNot = [isnegated(t) ? :($(t.args[2])) : t for t in traits]
    trait_args_noNot = length(trait_args_noNot)==1 ? trait_args_noNot[1] : :($curmod.TraitIntersection{Tuple{$(trait_args_noNot...)}})
    if init # the wrapper/trait-dispatch function:
        return :($fname{$(tpara...)}($(args...)) = (Base.@_inline_meta(); $fname($curmod.trait($trait_args_noNot), $(strip_tpara(args)...))))
        # TODO:
        #  - return also logic functions returning a nice error

    else # the logic:
        fbody = tfn.args[2]
        if hasmac
            logic = :(@dummy $fname{$(tpara...)}(::Type{$trait_args}, $(args...)) = $fbody)
            logic.args[1] = mac # replace @dummy
        else
            logic = :($fname{$(tpara...)}(::Type{$trait_args}, $(args...)) = $fbody)
        end
        # TODO:
        # - could a error be thrown if a logic is added for a trait which is not wrapped?
        return logic
    end
end
"""
Defines a function dispatching on a trait.

First initialize it to let it know on which trait it dispatches
```
@traitfn f{X,Y;  Tr1{X,Y}}(x::X,y::Y)
```
then add trait methods:
```
@traitfn f{X,Y;  Tr1{X,Y}}(x::X,y::Y) = ...
@traitfn f{X,Y; !Tr1{X,Y}}(x::X,y::Y) = ... # which is just sugar for:
@traitfn f{X,Y; Not{Tr1{X,Y}}}(x::X,y::Y) = ...
```

CAUTION: trying to dispatch on trait not initialized will not work:
```
@traitfn f{X;  Tr2{X}}(x::X) = ... # this will never be called
```

However, this is all fine:
```
@traitfn g{X;   Tr1{X}}(x::X)
@traitfn g{X;   Tr1{X}}(x::X) = ...
@traitfn g{X;  !Tr1{X}}(x::X) = ...    # ok, to do both the trait and its negation
@traitfn g{X;   Tr2{X}}(x::X, y)       # ok, as method signature is different to above
@traitfn g{X;   Tr2{X}}(x::X, y) = ...
@traitfn g{X;  !Tr2{X}}(x::X, y) = ...
```

Note, when updating a method, then re-initialize the trait function as
otherwise the old one is cached:
```
@traitfn g{X;   Tr1{X}}(x::X)
@traitfn g{X;   Tr1{X}}(x::X) = new-logic
```

### Dispatching on several traits

Is possible using this syntax:
```
@traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y)
@traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y) = 1
@traitfn f55{X, Y; !TT1{X},  TT2{Y}}(x::X, y::Y) = 2
@traitfn f55{X, Y;  TT1{X}, !TT2{Y}}(x::X, y::Y) = 3

```
Note that all methods need to feature the same traits (possibly
negated) in the same order.  Any method violating that will never be
called (and no error is thrown!).
"""
macro traitfn(tfn)
    esc(traitfn(tfn))
end

######
## Helpers
######

# true if :(!(...))
isnegated(t::Expr) = t.head==:call  && t.args[1]==:!

# [:(x::X)] -> [:x]
# also takes care of :...
strip_tpara(args::Vector) = Any[strip_tpara(a) for a in args]
strip_tpara(a::Symbol) = a
function strip_tpara(a::Expr)
    if a.head==:(::)
        return a.args[1]
    elseif a.head==:...
        return Expr(:..., strip_tpara(a.args[1]))
    else
        error("Cannot parse argument: $a")
    end
end

# insert dummy: ::X -> gensym()::X
# also takes care of :...
insertdummy(args::Vector) = Any[insertdummy(a) for a in args]
insertdummy(a::Symbol) = a
function insertdummy(a::Expr)
    if a.head==:(::) && length(a.args)==1
        return Expr(:(::), gensym(), a.args[1])
    elseif a.head==:...
        return Expr(:..., insertdummy(a.args[1]))
    else
        return a
    end
end

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

"Trait which contains all types"
@traitdef IsAnything{X}
@traitimpl IsAnything{Any}
"Trait which contains no types"
typealias IsNothing{X} Not{IsAnything{X}}
# TODO what about IsAnything{X,Y} ?

include("base-traits.jl")

end # module
