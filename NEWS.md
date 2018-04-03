# 2018-02-19

Transitioned to where-function syntax, but it can only supported in Julia 0.7.

Dropped Julia 0.6 support.  The last release-versions supporting it are v0.6.x.

# 2017-11-23

Dropped Julia 0.5 support, last release supporting it is v0.5.1


# 2016-11-19

Ditched Julia 0.4 support

Now new invocation: `@traitimpl IsBits{X} <- isbits(X)`

# 2016-10-13

Implemented Traitor.jl-like syntax.

Now using MacroTools.jl, makes to code look nicer.
