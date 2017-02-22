module BaseTraits
using SimpleTraits

using Compat

export IsLeafType, IsBits, IsImmutable, IsContiguous, IsIndexLinear,
       IsAnything, IsNothing, IsCallable, IsIterable

"Trait which contains all types"
@traitdef IsAnything{X}
@traitimpl IsAnything{X} <- (x->true)(X)

"Trait which contains no types"
@compat const IsNothing{X} = Not{IsAnything{X}}


"Trait of all isbits-types"
@traitdef IsBits{X}
@traitimpl IsBits{X} <- isbits(X)

"Trait of all immutable types"
@traitdef IsImmutable{X}
@traitimpl IsImmutable{X}  <- (X->!X.mutable)(X)

"Trait of all callable objects"
@traitdef IsCallable{X}
@traitimpl IsCallable{X} <- (X->(X==Function ||  length(methods(call, (X,Vararg)))>0))(X)

"Trait of all leaf types types"
@traitdef IsLeafType{X}
@traitimpl IsLeafType{X} <- isleaftype(X)

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

# TODO
## @traitdef IsArray{X} # use for any array like type in the sense of container
##                   # types<:AbstractArray are automatically part

## @traitdef IsMartix{X} # use for any LinearOperator
##                    # types<:AbstractArray are automatically part


Base.@deprecate_binding IsFastLinearIndex IsIndexLinear

@traitdef IsIterable{X}
@generated function SimpleTraits.trait{X}(::Type{IsIterable{X}})
    method_exists(start, Tuple{X}) ? :(IsIterable{X}) : :(Not{IsIterable{X}})
end

end # module
