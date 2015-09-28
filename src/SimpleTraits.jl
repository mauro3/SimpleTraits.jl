# This adds a few convenience functions & macros around Holy Traits.
module SimpleTraits
const curmod = module_name(current_module())

export Trait, istrait, @traitdef, @traitimpl, @traitfn, Not,
       IsAnything, IsNothing

# General trait exception
type TraitException <: Exception
    msg::AbstractString
end

"""
All Traits are subtypes of the abstract type Trait.  The parameter
SUPER contains the Intersection of the super traits for a particular
trait.
"""
abstract Trait{SUPER} # SUPER<:Intersection but that is not possible
# a concrete Trait will look like
## immutable Tr1{X,Y} <: Trait end
# where X and Y are the types involved in the trait.
# function Base.show{T<:Trait}(io::IO, Tr::Type{T})
#     invoke(show, Tuple{IO, DataType}, io, Tr)
#     print(" (a Trait)\n")
# end

"""
The trait of all types not belonging to a trait is encoded by wrapping
it with Not{}, e.g.  Not{Tr1{X,Y}}
"""
immutable Not{T<:Trait} <: Trait end
# Helper to strip an even number of Not{}s off: Not{Not{T}}->T
stripNot{T<:Trait}(::Type{T}) = T
stripNot{T<:Trait}(::Type{Not{T}}) = Not{T}
stripNot{T<:Trait}(::Type{Not{Not{T}}}) = stripNot(T)

"""
`Collection` is used internally when defining a trait-method
like so
```
@traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y)
@traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y) = 1
@traitfn f55{X, Y; !TT1{X},  TT2{Y}}(x::X, y::Y) = 2
@traitfn f55{X, Y; !TT1{X}, !TT2{Y}}(x::X, y::Y) = 3
```

It encodes the collection of traits `((TT1{X}, TT2{Y}),(!TT1{X},
TT2{Y}),(TT1{X}, !TT2{Y}),(!TT1{X}, !TT2{Y}))`.  Therefore, it is not
a single trait but kind of several traits.  This is just used inside
trait-functions and should not be used directly.
"""
typealias Collection Tuple
# TODO: should `typealias Collection Union` ?


"""
Constructs the intersection of several traits.  A type(-tuple) belongs
to a intersection if all its traits are fulfilled.
"""
immutable Intersection{S<:Tuple} <: Trait end
# TODO: should S<:Union?
# function Base.show{T<:Tuple}(io::IO, ti::Type{Collection{T}})
#     println(io, "Collection of:")
#     for Tr in T.parameters
#         print(io, " ")
#         if Tr<:Collection
#             show(io, Tr)
#         else
#             invoke(show, Tuple{IO, DataType}, io, Tr)
#         end
#         print(io, "\n")
#     end
# end


## Trait Union:
# """
# A new trait can be created from the union of several other
# (sub-)traits.  A type(-tuple) belongs to this trait if at least one of its
# sub-traits are fulfilled.
#
# TODO: maybe implement this?
# """
# Constructs the union of several traits.  A type(-tuple) belongs
# to a union if at least one of its traits is fulfilled.
# """
# immutable TUnion{S<:Tuple} <: Trait end



"""
A trait is defined as full filled if this function is the identity
function for that trait. Otherwise it returns the trait wrapped in `Not`.

Example:
```
trait(IsBits{Int}) # returns IsBits{Int}
trait(IsBits{Array}) # returns Not{IsBits{Array}}
```

Instead of using `@traitimpl` one can define a method for `trait` to
implement a trait.  If this uses `@generated` functions it should be
in-lined away.  For example the `IsBits` trait is defined by:
```
@traitdef IsBits{X}
@generated trait{X}(::Type{IsBits{X}}) = isbits(X) ? :(IsBits{X}) : :(Not{IsBits{X}})
```
"""
trait{T<:Trait}(::Type{T}) = Not{T}
trait{T<:Trait}(::Type{Not{T}}) = trait(T)

"""
Collections and Intersections use a generated method of the `trait` function to
evaluate whether a trait is fulfilled or not.  If a new type is added
to a trait it can mean that this generated function is out of sync.
Use this macro to re-initialize it. (Triggers a warning)
"""
macro reset_trait_collections()
    # TODO:
    # - make specific to one trait-collection/trait-function
    # - is it possible to make this cleaner?
    out = esc(:out46785) # poor man's gensym
#    TT = esc(:TT73840)  # leads to strange error!
    TT = esc(gensym())

    TTT = esc(:TT73840)
    quote
        @generated function SimpleTraits.trait{$TT<:Collection}(::Type{$TT})
            $out = Any[]
            for T in $TT.parameters
                if !(T<:Trait)
                    error("Need a tuple of traits")
                end
                push!($out, trait(T))
            end
            return :(Collection{$(out46785...)})
        end
        @generated function SimpleTraits.trait{$TTT<:Collection}(::Type{Intersection{$TTT}}) # this fn relies on <:Collection
            if trait($TTT)===$TTT
                return :(Intersection{$TT73840})
            else
                return :(Not{Intersection{$TT73840}})
            end
        end
    end
end
@reset_trait_collections # initialize it

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
                                                                        # with @traitimpl

"""
Used to define a trait.  Style wise I advocate the following:

- Traits, like types, are camel cased.
- Often they start with `Is` or `Has`.

Examples:
```
@traitdef IsFast{X}
@traitdef IsSlow{X,Y}
```
"""
macro traitdef(tr)
    if tr.head==:curly
        :(immutable $(esc(tr)) <: Trait end)
    elseif tr.head==:tuple || tr.head==:comparison # trait inheritance
        if tr.head==:comparison
            supert = Any[esc(tr.args[3])]
            tr = tr.args[1]
        else
            supert = Any[esc(tr.args[1].args[3]), map(esc, tr.args[2:end])...]
            tr = tr.args[1].args[1]
        end
        ## There are a few options to handle this:
        ## Error: (I)
        # return :(throw(TraitException("Sub-traiting is not supported")))
        ## Or proper supertrait  (II)
        :(immutable $(esc(tr)) <: Trait{Intersection{Tuple{$(supert...)}}} end)
        ## Or alias  (III)
        # :(typealias $(esc(tr)) Collection{Tuple{$(supert...)}})
    else
        throw(TraitException(
        "Either define trait as `@traitdef Tr{...}` or with one or more super-traits `@traitdef Tr{...} <: Tr1, Tr2`"))
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

This errors if super-traits are not defined.
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
        $trname <: Intersection && error("Cannot use @traitimpl with Trait-Intersection: implement each intersected trait by hand.")
        check_supertraits($(esc(tr)))
        # TODO: allow option to implement all supertypes as well
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
    trait_args = length(trait_args)==1 ? trait_args[1] : :(Tuple{$(trait_args...)})
    # TODO: add test to throw on @traitfn f56{X,Y; !(T4{X,Y}, T{X})}(x::X, y::Y)

    trait_args_noNot = [isnegated(t) ? :($(t.args[2])) : t for t in traits]
    trait_args_noNot = length(trait_args_noNot)==1 ? trait_args_noNot[1] : :(Tuple{$(trait_args_noNot...)})
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

Is possible to dispatch on several traits using this syntax:
```
@traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y)
@traitfn f55{X, Y;  TT1{X},  TT2{Y}}(x::X, y::Y) = 1
@traitfn f55{X, Y; !TT1{X},  TT2{Y}}(x::X, y::Y) = 2
@traitfn f55{X, Y;  TT1{X}, !TT2{Y}}(x::X, y::Y) = 3

```
*Note that all methods need to feature the same traits (possibly
negated) in the same order!*  Any method violating that will never be
called (and no error is thrown!).
"""
macro traitfn(tfn)
    esc(traitfn(tfn))
end

######
## Helpers
######

"""Returns the super traits"""
function getsuper{T<:Trait}(t::Type{T})
    S = t.super.parameters[1]
    if isa(S,TypeVar)
        return Base.Core.svec()
    else
        return S.parameters[1].parameters
    end
end
getsuper{T<:Intersection}(t::Type{T}) =  t.parameters[1].parameters

"""
Checks whether all supertraits are fulfilled.  If not, throws an error.
"""
check_supertraits(::Any) = error("Argument to `check_supertraits` is not a Trait.")
function check_supertraits{T<:Trait}(tr::Type{T})
    for ST in getsuper(tr)
        if !istrait(ST)
            throw(TraitException("Super trait $ST is not fulfilled.  If it should be fulfilled, run `@traitimpl $ST` first."))
        end
    end
end


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
