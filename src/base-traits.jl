module BaseTraits
using SimpleTraits
import SimpleTraits: trait

export IsLeafType, IsBits, IsImmutable, IsContiguous, IsFastLinearIndex,
       IsAnything, IsNothing, IsCallable

"Trait which contains all types"
@traitdef IsAnything{X}
trait{X}(::Type{IsAnything{X}}) = IsAnything{X}

"Trait which contains no types"
typealias IsNothing{X} Not{IsAnything{X}}


"Trait of all isbits-types"
@traitdef IsBits{X}
@generated trait{X}(::Type{IsBits{X}}) =
    isbits(X) ? :(IsBits{X}) : :(Not{IsBits{X}})

"Trait of all immutable types"
@traitdef IsImmutable{X}
@generated trait{X}(::Type{IsImmutable{X}}) =
    X.mutable ? :(Not{IsImmutable{X}}) : :(IsImmutable{X})

"Trait of all callable objects"
@traitdef IsCallable{X}
@generated trait{X}(::Type{IsCallable{X}}) =
    (X==Function ||  length(methods(call, (X,Vararg)))>0) ? IsCallable{X} : Not{IsCallable{X}}

"Trait of all leaf types types"
@traitdef IsLeafType{X}
@generated trait{X}(::Type{IsLeafType{X}}) = isleaftype(X) ? :(Not{IsLeafType{X}}) : :(IsLeafType{X})

"Types which have contiguous memory layout"
@traitdef IsContiguous{X} # https://github.com/JuliaLang/julia/issues/10889
@generated trait{X}(::Type{IsContiguous{X}}) =
    Base.iscontiguous(X) ? :(IsContiguous{X}) : :(Not{IsContiguous{X}})

"Array indexing trait."
@traitdef IsFastLinearIndex{X} # https://github.com/JuliaLang/julia/pull/8432
@generated function trait{X}(::Type{IsFastLinearIndex{X}})
    if Base.linearindexing(X)==Base.LinearFast()
        return :(IsFastLinearIndex{X})
    elseif  Base.linearindexing(X)==Base.LinearSlow()
        return :(Not{IsFastLinearIndex{X}})
    else
        error("Not recognized")
    end
end

# TODO
## @traitdef IsArray{X} # use for any array like type in the sense of container
##                   # types<:AbstractArray are automatically part

## @traitdef IsMartix{X} # use for any LinearOperator
##                    # types<:AbstractArray are automatically part

end # module
