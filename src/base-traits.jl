module BaseTraits
using SimpleTraits
export IsBits, IsImmutable, IsContiguous, IsFastLinearIndex

@traitdef IsBits{X}
@traitdef IsImmutable{X}

if VERSION<v"0.4-"
    # otherwise errors
    macro generated(x)
        x
    end
end

# TODO
## @traitdef IsArray{X} # use for any array like type in the sense of container
##                   # types<:AbstractArray are automatically part

## @traitdef IsMartix{X} # use for any LinearOperator
##                    # types<:AbstractArray are automatically part


if VERSION>v"0.4-" # use @generated functions
    @traitdef IsContiguous{X} # https://github.com/JuliaLang/julia/issues/10889
    @traitdef IsFastLinearIndex{X} # https://github.com/JuliaLang/julia/pull/8432
    
    @generated SimpleTraits.trait{X}(::Type{IsBits{X}}) =
        isbits(X) ? :(IsBits{X}) : :(Not{IsBits{X}})

    @generated SimpleTraits.trait{X}(::Type{IsImmutable{X}}) =
        X.mutable ? :(Not{IsImmutable{X}}) : :(IsImmutable{X})

    @generated SimpleTraits.trait{X}(::Type{IsContiguous{X}}) =
        Base.iscontiguous(X) ? :(IsContiguous{X}) : :(Not{IsContiguous{X}})
        

    @generated function SimpleTraits.trait{X}(::Type{IsFastLinearIndex{X}})
        if Base.linearindexing(X)==Base.LinearFast()
            return :(IsFastLinearIndex{X})
        elseif  Base.linearindexing(X)==Base.LinearSlow()
            return :(Not{IsFastLinearIndex{X}})
        else
            error("Not recognized")
        end
    end

    
    
else # no generated functions in 0.3, this will probably result in
    # runtime dispatch but will be compatible with 0.4
    #
    # TODO make a macro producing both generated and not generated
    
    SimpleTraits.trait{X}(::Type{IsBits{X}}) =
        isbits(X) ? IsBits{X} : Not{IsBits{X}}

    SimpleTraits.trait{X}(::Type{IsImmutable{X}}) =
        X.mutable ? Not{IsImmutable{X}} : IsImmutable{X}

end

end # module
