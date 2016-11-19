module BaseTraits
using SimpleTraits

export IsLeafType, IsBits, IsImmutable, IsContiguous, IsFastLinearIndex,
       IsAnything, IsNothing, IsCallable

"Trait which contains all types"
@traitdef IsAnything{X}
@traitimpl IsAnything{X} <- (x->true)(X)

"Trait which contains no types"
typealias IsNothing{X} Not{IsAnything{X}}


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
@traitdef IsFastLinearIndex{X} # https://github.com/JuliaLang/julia/pull/8432
function islinearfast(X)
    if Base.linearindexing(X)==Base.LinearFast()
        return true
    elseif  Base.linearindexing(X)==Base.LinearSlow()
        return false
    else
        error("Not recognized")
    end
end
@traitimpl IsFastLinearIndex{X} <- islinearfast(X)

# TODO
## @traitdef IsArray{X} # use for any array like type in the sense of container
##                   # types<:AbstractArray are automatically part

## @traitdef IsMartix{X} # use for any LinearOperator
##                    # types<:AbstractArray are automatically part

end # module
