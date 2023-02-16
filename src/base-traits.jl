module BaseTraits
using SimpleTraits


export IsLeafType, IsConcrete, IsBits, IsImmutable, IsContiguous, IsIndexLinear,
       IsAnything, IsNothing, IsCallable, IsIterator

"Trait which contains all types"
@traitdef IsAnything{X}
@traitimpl IsAnything{X} <- (x->true)(X)

"Trait which contains no types"
@traitdef IsNothing{X}
@traitimpl IsNothing{X} <- (x->false)(X)

"Trait of all isbits-types"
@traitdef IsBits{X}
_isbits(X) = isbitstype(X)
@traitimpl IsBits{X} <- _isbits(X)

"Trait of all immutable types"
@traitdef IsImmutable{X}
if VERSION >= v"1.7.0-DEV.1279"
    _isimmutable(X) = !(Base.ismutabletype(X))
else
    _isimmutable(X) = !X.mutable
end
@traitimpl IsImmutable{X}  <- _isimmutable(X)

"Trait of all callable objects"
@traitdef IsCallable{X}
@traitimpl IsCallable{X} <- (X->(X<:Function ||  length(methods(X))>0))(X)

"Trait of all concrete types types"
@traitdef IsConcrete{X}
@traitimpl IsConcrete{X} <- isconcretetype(X)

Base.@deprecate_binding IsLeafType IsConcrete

"Types which have contiguous memory layout"
@traitdef IsContiguous{X} # https://github.com/JuliaLang/julia/issues/10889
@traitimpl IsContiguous{X} <- Base.iscontiguous(X)

"Array indexing trait."
@traitdef IsIndexLinear{X} # https://github.com/JuliaLang/julia/pull/8432
function isindexlinear(X)
    if IndexStyle(X)==IndexLinear()
        return true
    elseif  IndexStyle(X)==IndexCartesian()
        return false
    else
        error("Not recognized")
    end
end
@traitimpl IsIndexLinear{X} <- isindexlinear(X)

Base.@deprecate_binding IsFastLinearIndex IsIndexLinear

# TODO
## @traitdef IsArray{X} # use for any array like type in the sense of container
##                   # types<:AbstractArray are automatically part

## @traitdef IsMartix{X} # use for any LinearOperator
##                    # types<:AbstractArray are automatically part


"""
Trait of all iterator types.

NOTE: using this will lead to dynamic dispatch, see
https://github.com/mauro3/SimpleTraits.jl/issues/40 for context.
"""
@traitdef IsIterator{X}
function SimpleTraits.trait(::Type{IsIterator{X}}) where {X}
    hasmethod(iterate, Tuple{X}) ? IsIterator{X} : Not{IsIterator{X}}
end

end # module
