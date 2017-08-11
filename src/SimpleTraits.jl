__PRECOMPILE__()

module SimpleTraits
using Base.Iterators
using MacroTools
using Compat
const curmod = module_name(current_module())

# This is basically just adding a few convenience functions & macros
# around Holy Traits.

export Trait, istrait, @traitdef, @traitimpl, @traitfn, Not, @check_fast_traitdispatch

# All traits are concrete subtypes of this trait.  SUPER is not used
# but present to be compatible with Traits.jl.
## @doc """
## `abstract Trait{SUPER}`

"""
All Traits are subtypes of abstract type Trait.

A concrete Trait will look like:
```julia
immutable Tr1{X,Y} <: Trait end
```
where X and Y are the associated types of the trait.

(Not, as before the types involved in the trait.)
"""
abstract type Trait end

"""
The set of all types not belonging to a trait is encoded by wrapping
it with Not{}, e.g.  Not{Tr1{X,Y}}
"""
struct Not{T<:Trait} <: Trait end

# # Helper to strip an even number of Not{}s off: Not{Not{T}}->T
# stripNot{T<:Trait}(::Type{T}) = T
# stripNot{T<:Trait}(::Type{Not{T}}) = Not{T}
# stripNot{T<:Trait}(::Type{Not{Not{T}}}) = stripNot(T)

"""
This function checks whether a trait is fulfilled by a specific
set of types.
```
istrait(Tr1{Int,Float64}) => return true or false
```
"""
istrait(::Any) = error("Argument is not a Trait.")
istrait(::Not) = false
istrait(::Trait) = true

"""

Used to define a trait.  Traits, like types, are camel cased.  I
suggest to start them with a verb, e.g. `IsImmutable`, to distinguish
them from actual types, which are usually nouns.

Traits need to have one or more (type-)parameters to specify the type to which
the trait is applied, these go in parentheise `(...)`.  For instance `@traitdef
IsImmutable(T)`.  When actually calling the constructor `IsImmutable(MyType)`,
then it will return `IsImmutable()`, if `MyType` is part of the trait or
`Not{IsImmutable}()` otherwise. Most traits will be one-type-parameter traits,
however, several type-parameters are useful when there is a "contract" between
several types.

Additionally, traits can have associated types, which are very similar to
type-parameters of ordinary types.  For instance if we wanted a iterator-trait
which can also be used to dispatch on the type of the iterated values, we may
want something like `@traitdef IsIterator{ElType}(X)`.  Now (once implemented
correctly), `IsIterator([1,2])` would return `IsIterator{Int}()`, signifiying
that the iteration would be over `Int`s.

Note that the trait-constructors can be called both with types and instances:
`IsIterator([1,2])` and `IsIterator(Vector{Int})` both return `IsIterator{Int}()`.

Examples:
```julia
@traitdef IsFast(X)
@traitdef IsSlow(X,Y)
@traitdef LikeArray{T,N}(Ar) # with associated types
```
"""
function traitdef(tr)
    Tr, A, T = @match tr begin
        (
            Tr_{A__}(T__)
            |
            Tr_(T__)
        ) => (Tr, A, T)
    end
    # make default constructors
    trname = esc(Tr)
    f1 = :( $trname(::Any...) = (len=$(length(T)); error("This is a $len-type trait") ) )
    args = [:(::Type) for i=1:length(T)]
    f2 = :($trname($(args...)) = Not{$trname}()) # default: not belonging to trait
    args = [:(tv) for tv in take(GenerateTypeVars{:lcase}(),length(T))]
    tpof = [:(typeof(tv)) for tv in take(GenerateTypeVars{:lcase}(),length(T))]
    f3 = :($trname($(args...)) = $trname($(tpof...))) # convert instances to types
    if A==nothing
        return quote
            struct $trname <: Trait end
            $f1
            $f2
            $f3
        end
    else
        tmp = esc(:($Tr{$(A...)}))
        tmp2 = map(esc,A)
        f4 = :($tmp($(args...)) where {$(tmp2...)} = Not{$tmp}())
        return quote
            struct $tmp <: Trait end
            $f1
            $f2
            $f3
            $f4
        end
    end
end
macro traitdef(tr)
    traitdef(tr)
end

"""
Used to add a type or type-tuple to a trait.  By default a type does
not belong to a trait.

Example:
```julia
@traitdef IsFast(X)
@traitimpl IsFast(Array{Int,1})
@traitimpl IsFast(Array{T,2}) where T
```
where the last one shows how use `where` for free type-parameters.

Often a trait is dependent on some check-function returning true or
false.  This can be done with:
```julia
@traitimpl IsFast(T) <- isfast(T)
```
where `isfast` is that check-function.

Note that traits implemented with the former of above methods will
override an implementation with the latter method.  Thus it can be
used to define exceptions to the rule.

When there are associated types, these need to be specifed too:
```julia
@traitdef IsIterator{T}(X)
@traitimpl IsIterator{Int}(Array{Int,1})
@traitimpl IsIterator{T}(Array{T}) where T
```
(depending on the type involved the order of `{T,N}` maybe different).`

TODO:

```julia
@traitimpl LikeArray{T,N}(AR) <- likearray(AR)
```
where `likearray` is that check-function, which now also needs to return a type
tuple `{T,N}` as second argument.

Note that also negated traits can be implemented, say to make an exception to a
rule: `@traitimpl Not{IsFast}(Array{Float64,1})`.`

"""
macro traitimpl(tr)
    if tr.head==:where
        Ps = tr.args[2:end]
        ps = map(esc, Ps)
        tr = tr.args[1]
        haswhere = true # e.g. @traitimpl IsIterator{T}(Array{T}) where T
    else
        haswhere = false
    end
    if tr.head==:call && tr.args[1]!=:<
        out = @match tr begin
            (   (
                Not{Tr_{A__}}(T__)
                )|(
                !Tr_{A__}(T__)
                )|(
                Not{Tr_}(T__)
                )|(
                Tr_{A__}(T__)
                )|(
                !Tr_(T__)
                )|(
                Tr_(T__)
                )
            ) => (Tr, A, T)
        end
        if out==nothing
            error("Could not parse $tr")
        else
            Tr, A, Typs = out
        end
        hasassoc = A!=nothing
        trname = esc(Tr)
        typs = [:(::Type{$T}) for T in Typs]
        typs = map(esc, typs)

        if !hasassoc
            if !isnegated(tr)
                if haswhere
                    return :( ( $trname($(typs...)) ) where {$(ps...)} = $trname(); nothing)
                else
                    return :( $trname($(typs...)) = $trname(); nothing)
                end
            else
                if haswhere
                    return :( $trname($(typs...)) where {$(ps...)} = Not{$trname}(); nothing)
                else
                    return :( $trname($(typs...)) = Not{$trname}(); nothing)
                end
            end
        else # with associated types
            assoc = map(esc, A)
            if !isnegated(tr)
                if haswhere
                    return quote
                        $trname($(typs...)) where {$(ps...)} = $trname{$(assoc...)}()
                        nothing
                    end
                else
                    return :( $trname($(typs...)) = $trname{$(assoc...)}() ; nothing )
                end
            else
                if haswhere
                    return quote
                         $trname($(typs...)) where {$(ps...)} = Not{$trname{$(assoc...)}}()
                         nothing
                    end
                else
                    return :( $trname($(typs...)) = Not{$trname{$(assoc...)}}(); nothing)
                end
            end
        end
    elseif tr.head==:call # @traitimpl IsFast(T) <- isfast(T)
        error("not implemented yet")
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
                trait = :(!($(trait0.args[2])($typ)))
                trait_wo_assoc = :(!($(trait0.args[2].args[1])($typ)))
                assocs = trait0.args[2].args[2:end]
            else
                trait = :($trait0($typ))
                trait_wo_assoc = :($(trait0.args[1])($typ))
                assocs = trait0.args[2:end]
            end
            typs_wo_assoc = [t for t in typs if !(t in assocs)]

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
            trait0_opposite = trait0 # opposite of `trait` below a372s that gets stripped of !
            trait = trait.args[2]
            val = :(::$curmod.Not{$(trait.args[1])})
        else
            trait0_opposite = Expr(:call, :!, trait0)  # generate the opposite
            val = :(::$(trait.args[1]))
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
                    # TODO: remove the types here and use the instances instead
                    $fname{$(typs_wo_assoc...)}($(args1...)) = (Base.@_inline_meta(); $fname($trait_wo_assoc,
                                                                                    $(strip_tpara(strip_kw(args1))...)
                                                                                    )
                                                       )
                    $ex
                end
            else
                ex = quote
                    $fname{$(typs_wo_assoc...)}($(args1...);kwargs...) = (Base.@_inline_meta(); $fname($trait_wo_assoc,
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
        return ex
    end
end
"""
Defines a function dispatching on a trait. Examples:

```julia
@traitfn f{X;  Tr1(X)}(x::X,y) = ...
@traitfn f{X; !Tr1(X)}(x::X,y) = ...

@traitfn f{X,Y;  Tr2(X,Y)}(x::X,y::Y) = ...
@traitfn f{X,Y; !Tr2(X,Y)}(x::X,y::Y) = ...
```
or using Traitor-style syntax:
```
@traitfn f(x::::Tr1, y) = ...
@traitfn f(x::::(!Tr1), y) = ...
```

Note that the second example is just syntax sugar for
`@traitfn f{X,Y; Not{Tr1{X,Y}}}(x::X,y::Y) = ...`.
"""
macro traitfn(tfn)
    esc(traitfn(tfn))
end

######
## Helpers
######

# true if :(!(Tr{x}))
function isnegated(t::Expr)
    out = @match t begin
        !Tr_{P__}() => true
        Tr_{P__}() => false
        !Tr_{P__} => true
        Tr_{P__} => false
        Not{Tr_{P__}}() => true
        Not{Tr_{P__}} => true
        !Tr_() => true
        Tr_() => false
        !Tr_ => true
        Tr_ => false
        Not{Tr_}() => true
        Not{Tr_} => true
    end
    out==nothing && error("Wat! A bug!")
    return out
end
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
struct GenerateTypeVars{CASE} end
Base.start(::GenerateTypeVars) = 1
Base.next(::GenerateTypeVars{:upcase}, state) = (Symbol("X$state"), state+1) # X1,..
Base.next(::GenerateTypeVars{:lcase}, state) = (Symbol("x$state"), state+1)  # x1,...
Base.done(::GenerateTypeVars, state) = 10^6<state
Base.length(::GenerateTypeVars) = 10^6

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

# # This does not work.  Errors on compilation with:
# # ERROR: LoadError: UndefVarError: Tr not defined
# function check_traitdispatch(Tr; nlines=5, Args=(Int,))
#     @traitfn fn_test(x::::Tr) = 1
#     @traitfn fn_test(x::::(!Tr)) = 2
#     @assert llvm_lines(fn_test, Args) == nlines
# end


"""
    check_fast_traitdispatch(Tr, Args=(Int,), nlines=6, verbose=false)

Macro to check whether a trait-dispatch is fast (i.e. as fast as an
ordinary function call) or whether dispatch is slow (dynamic).  Only
works with single parameters traits (so far).

Optional arguments are:
- Type parameter to the trait (default `Int`)
- Verbosity (default `false`)

Example:

    @check_fast_traitdispatch IsBits
    @check_fast_traitdispatch IsBits String true

NOTE: This only works when code-coverage is disabled!  Thus, do not
use this macro in tests (or disable `coverage=true` in your
`.travis.yml` script), or it will error.

TODO: This is rather ugly.  Ideally this would be a function but I ran
into problems, see source code.  Also the macro is ugly.  PRs welcome...
"""
macro check_fast_traitdispatch(Tr, Arg=:Int, verbose=false)
    if Base.JLOptions().code_coverage==1
        warn("The SimpleTraits.@check_fast_traitdispatch macro only works when running Julia without --code-coverage")
        return nothing
    end
    test_fn = gensym()
    test_fn_null = gensym()
    nl = gensym()
    nl_null = gensym()
    out = gensym()
    esc(quote
        $test_fn_null(x) = 1
        $nl_null = SimpleTraits.llvm_lines($test_fn_null, ($Arg,))
        @traitfn $test_fn(x::::$Tr) = 1
        @traitfn $test_fn(x::::(!$Tr)) = 2
        $nl = SimpleTraits.llvm_lines($test_fn, ($Arg,))
        $out = $nl == $nl_null
        if $verbose && !$out
            println("Number of llvm code lines $($nl) but should be $($nl_null).")
        end
        $out
    end)
end

"Returns number of llvm-IR lines for a call of function `fn` with argument types `args`"
function llvm_lines(fn, args)
    io = IOBuffer()
    Base.code_llvm(io, fn, args)
    #Base.code_native(io, fn, args)
    count(c->c=='\n', String(io))
end

# include("base-traits.jl")

end # module
