__precompile__()

module SimpleTraits
using MacroTools
using Compat
const curmod = module_name(current_module())

# This is basically just adding a few convenience functions & macros
# around Holy Traits.

export Trait, istrait, @traitdef, @traitimpl, @traitfn, Not

# All traits are concrete subtypes of this trait.  SUPER is not used
# but present to be compatible with Traits.jl.
## @doc """
## `abstract Trait{SUPER}`

@compat abstract type Trait end #{SUPER}

"""
All Traits are subtypes of abstract type Trait.

A concrete Trait will look like:
```julia
immutable Tr1{X,Y} <: Trait end
```
where X and Y are the types involved in the trait.


(SUPER is not used here but in Traits.jl, thus retained for possible
future compatibility.)
"""
Trait

@compat abstract type Not{T<:Trait} <: Trait end

"""
The set of all types not belonging to a trait is encoded by wrapping
it with Not{}, e.g.  Not{Tr1{X,Y}}
"""
Not

# Helper to strip an even number of Not{}s off: Not{Not{T}}->T
stripNot{T<:Trait}(::Type{T}) = T
stripNot{T<:Trait}(::Type{Not{T}}) = Not{T}
stripNot{T<:Trait}(::Type{Not{Not{T}}}) = stripNot(T)

"""
A trait is defined as full-filled if this function is the identity
function for that trait.  Otherwise it returns the trait wrapped in
`Not`.

Example:
```
trait(IsBits{Int}) # returns IsBits{Int}
trait(IsBits{Array}) # returns Not{IsBits{Array}}
```

Usually this function is defined when using the `@traitimpl` macro.

However, instead of using `@traitimpl` one can define a method for
`trait` to implement a trait, see the README.
"""
trait{T<:Trait}(::Type{T}) = Not{T}
trait{T<:Trait}(::Type{Not{T}}) = trait(T)

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
                                                                        # thus is redefine when traits are defined
"""

Used to define a trait.  Traits, like types, are camel cased.  I
suggest to start them with a verb, e.g. `IsImmutable`, to distinguish
them from actual types, which are usually nouns.

Traits need to have one or more (type-)parameters to specify the type
to which the trait is applied.  For instance `IsImmutable{Int}`
signifies that `Int` is part of `IsImmutable` (although whether that
is true needs to be checked with the `istrait` function).  Most traits
will be one-parameter traits, however, several parameters are useful
when there is a "contract" between several types.

Examples:
```julia
@traitdef IsFast{X}
@traitdef IsSlow{X,Y}
```
"""
macro traitdef(tr)
    :(immutable $(esc(tr)) <: Trait end)
end

"""
Used to add a type or type-tuple to a trait.  By default a type does
not belong to a trait.

Example:
```julia
@traitdef IsFast{X}
@traitimpl IsFast{Array{Int,1}}
```

Often a trait is dependent on some check-function returning true or
false.  This can be done with:
```julia
@traitimpl IsFast{T} <- isfast(T)
```
where `isfast` is that check-function.

Note that traits implemented with the former of above methods will
override an implementation with the latter method.  Thus it can be
used to define exceptions to the rule.
"""
macro traitimpl(tr)
    if tr.head==:curly || (tr.head==:call && tr.args[1]==:!)
        # makes
        # trait{X1<:Int,X2<:Float64}(::Type{Tr1{X1,X2}}) = Tr1{X1,X2}
        if tr.args[1]==:Not || isnegated(tr)
            tr = tr.args[2]
            negated = true
        else
            negated = false
        end
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
        if !negated
            return quote
                $fnhead = $trname{$(paras...)}
                VERSION < v"0.6-" && ($isfnhead = true) # Add the istrait definition as otherwise
                # method-caching can be an issue.
            end
        else
            return quote
                $fnhead = Not{$trname{$(paras...)}}
                VERSION < v"0.6-" && ($isfnhead = false) # Add the istrait definition as otherwise
                # method-caching can be an issue.
            end
        end
    elseif tr.head==:call
        @assert tr.args[1]==:<
        negated,Tr,P1,fn,P2 = @match tr begin
            Not{Tr_{P1__}} <- fn_(P2__) => (true, Tr, P1, fn, P2)
            Tr_{P1__} <- fn_(P2__) => (false, Tr, P1, fn, P2)
        end
        if negated
            fn = Expr(:call, GlobalRef(SimpleTraits, :!), fn)
        end
        return esc(quote
            function SimpleTraits.trait{$(P1...)}(::Type{$Tr{$(P1...)}})
                return $fn($(P2...)) ? $Tr{$(P1...)} : Not{$Tr{$(P1...)}}
            end
        end)
    else
        error("Cannot parse $tr")
    end
end

# Defining a function dispatching on the trait (or not)
# @traitfn f{X,Y;  Tr1{X,Y}}(x::X,y::Y) = ...
# @traitfn f{X,Y; !Tr1{X,Y}}(x::X,y::Y) = ... # which is just sugar for:
# @traitfn f{X,Y; Not{Tr1{X,Y}}}(x::X,y::Y) = ...

dispatch_cache = Dict()  # to ensure that the trait-dispatch function is defined only once per pair
let
    global traitfn
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

        # Dissect AST into:
        # fbody: body
        # fname: symbol of name
        # args0: vector of all arguments except wags (without any gensym'ed symbols but stripped of Traitor-traits)
        # args1: like args0 but with gensym'ed symbols where necessary
        # kwargs: all kwargs
        # typs0: vector of all function parameters (without the trait-ones, no gensym'ed)
        # typs: vector of all function parameters (without the trait-ones, with gensym'ed for Traitor)
        # trait: expression of the trait
        # trait0: expression of the trait without any gensym'ed symbols
        #
        # (The variables without gensym'ed symbols are mostly used for the key of the dispatch cache)

        fhead = tfn.args[1]
        fbody = tfn.args[2]

        fname, paras, args0, kwargs = @match fhead begin
            f_{paras__}(args0__;kwargs__) => (f,paras,args0,kwargs)
            f_(args0__; kwargs__)           => (f,[],args0,kwargs)
            f_{paras__}(args0__) => (f,paras,args0,[])
            f_(args0__)           => (f,[],args0,[])
        end
        haskwargs = length(kwargs)>0
        if length(paras)>0 && isa(paras[1],Expr) && paras[1].head==:parameters
            # this is a Traits.jl style function
            trait = paras[1].args[1]
            trait0 = trait # without gensym'ed types, here identical
            typs = paras[2:end]
            typs0 = typs # without gensym'ed types, here identical
            args1 = insertdummy(args0)
        else
            # This is a Traitor.jl style function.  Change it into a Traits.jl function.
            # Find the traitor:
            typs0 = deepcopy(paras) # without gensym'ed types
            typs = paras
            out = nothing
            i = 0 # index of function argument with Traitor trait
            vararg = false
            for (i,a) in enumerate(args0)
                vararg = a.head==:...
                if vararg
                    a = a.args[1]
                end
                out = @match a begin
                    ::::Tr_           => (nothing,nothing,Tr)
                    ::T_::Tr_         => (nothing,T,Tr)
                    x_Symbol::::Tr_   => (x,nothing,Tr)
                    x_Symbol::T_::Tr_ => (x,T,Tr)
                end
                out!=nothing && break
            end
            out==nothing && error("No trait found in function signature")
            arg,typ,trait0 = out
            if typ==nothing
                typ = gensym()
                push!(typs, typ)
            end
            if isnegated(trait0)
                trait = :(!($(trait0.args[2]){$typ}))
            else
                trait = :($trait0{$typ})
            end
            args1 = deepcopy(args0)
            if vararg
                args0[i] = arg==nothing ? nothing : :($arg...).args[1]
                args1[i] = arg==nothing ? :(::$typ...).args[1] : :($arg::$typ...).args[1]
            else
                args0[i] = arg==nothing ? nothing : :($arg)
                args1[i] = arg==nothing ? :(::$typ) : :($arg::$typ)
            end
            args1 = insertdummy(args1)
        end

        # Process dissected AST
        if isnegated(trait)
            trait0_opposite = trait0 # opposite of `trait` below as that gets stripped of !
            trait = trait.args[2]
            val = :(::Type{$curmod.Not{$trait}})
        else
            trait0_opposite = Expr(:call, :!, trait0)  # generate the opposite
            val = :(::Type{$trait})
        end
        # Get line info for better backtraces
        ln = findline(tfn)
        if isa(ln, Expr)
            pushloc = Expr(:meta, :push_loc, ln.args[2], fname, ln.args[1])
            poploc = Expr(:meta, :pop_loc)
        else
           pushloc = poploc = nothing
        end
        # create the function containing the logic
        retsym = gensym()
        if hasmac
            fn = :(@dummy $fname{$(typs...)}($val, $(strip_kw(args1)...); $(kwargs...)) = ($pushloc; $retsym = $fbody; $poploc; $retsym))
            fn.args[1] = mac # replace @dummy
        else
            fn = :($fname{$(typs...)}($val, $(strip_kw(args1)...); $(kwargs...)) = ($pushloc; $retsym = $fbody; $poploc; $retsym))
        end
        # Create the trait dispatch function
        ex = fn
        key = (current_module(), fname, typs0, strip_kw(args0), trait0_opposite)
        if !(key ∈ keys(dispatch_cache)) # define trait dispatch function
            if !haskwargs
                ex = quote
                    $fname{$(typs...)}($(args1...)) = (Base.@_inline_meta(); $fname($curmod.trait($trait),
                                                                                    $(strip_tpara(strip_kw(args1))...)
                                                                                    )
                                                       )
                    $ex
                end
            else
                ex = quote
                    $fname{$(typs...)}($(args1...);kwargs...) = (Base.@_inline_meta(); $fname($curmod.trait($trait),
                                                                                              $(strip_tpara(strip_kw(args1))...);
                                                                                              kwargs...
                                                                                              )
                                                                 )
                    $ex
                end
            end
            dispatch_cache[key] = (haskwargs, args0)
        else # trait dispatch function already defined
            if dispatch_cache[key][1]!=haskwargs
                ex = :(error("""
                             Trait-functions can have keyword arguments.
                             But if so, add the same to both `Tr` and `!Tr`, but they can have different default values.
                             """))
            end
            if dispatch_cache[key][2]!=args0
                ex = :(error("""
                             Trait-functions can have default arguments.
                             But if so, add them to both `Tr` and `!Tr`, and they both need identical values!
                             """))
            end
            delete!(dispatch_cache, key) # permits function redefinition if that's what we want
        end
        ex
    end
end

"""
Defines a function dispatching on a trait. Examples:

```julia
@traitfn f{X;  Tr1{X}}(x::X,y) = ...
@traitfn f{X; !Tr1{X}}(x::X,y) = ...

@traitfn f{X,Y;  Tr2{X,Y}}(x::X,y::Y) = ...
@traitfn f{X,Y; !Tr2{X,Y}}(x::X,y::Y) = ...
```

Note that the second example is just syntax sugar for `@traitfn f{X,Y; Not{Tr1{X,Y}}}(x::X,y::Y) = ...`.
"""
macro traitfn(tfn)
    esc(traitfn(tfn))
end

######
## Helpers
######

# true if :(!(Tr{x}))
isnegated(t::Expr) = t.head==:call
isnegated(t::Symbol) = false

# [:(x::X)] -> [:x]
# also takes care of :...
strip_tpara(args::Vector) = Any[strip_tpara(a) for a in args]
strip_tpara(a::Symbol) = a
function strip_tpara(a::Expr)
    if a.head==:(::)
        return a.args[1]
    elseif a.head==:...
        return Expr(:..., strip_tpara(a.args[1]))
    elseif a.head==:kw
        @assert length(a.args)==2
        return Expr(:kw, strip_tpara(a.args[1]), a.args[2])
    else
        error("Cannot parse argument: $a")
    end
end


# [:(x::X=4)] -> [:x::X]
# i.e. strips defaults arguments
# also takes care of :...
strip_kw(args::Vector) = Any[strip_kw(a) for a in args]
strip_kw(a) = a
function strip_kw(a::Expr)
    if a.head==:(::) || a.head==:...
        return a
    elseif a.head==:kw
        @assert length(a.args)==2
        return a.args[1]
    else
        error("Cannot parse argument: $a")
    end
end


# insert dummy: ::X -> gensym()::X
# also takes care of :...
# not needed for kwargs
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
Base.next(::GenerateTypeVars{:upcase}, state) = (Symbol("X$state"), state+1) # X1,..
Base.next(::GenerateTypeVars{:lcase}, state) = (Symbol("x$state"), state+1)  # x1,...
Base.done(::GenerateTypeVars, state) = false

####
# Annotating the source location
####

function findline(ex::Expr)
    ex.head == :line && return ex
    for a in ex.args
        ret = findline(a)
        isa(ret, Expr) && return ret
    end
    nothing
end
findline(arg) = nothing

####
# Extras
####

include("base-traits.jl")

end # module
