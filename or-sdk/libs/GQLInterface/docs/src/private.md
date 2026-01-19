# Private

```@contents
Pages = ["private.md"]
```

Package internals documentation.

## Client

```@autodocs
Modules = [GQLInterface]
Pages = ["client.jl", "introspection.jl"]
Public = false
```

## Operations

```@autodocs
Modules = [GQLInterface]
Pages   = ["queries.jl", "mutations.jl", "subscriptions.jl", "http_execution.jl", "gqlresponse.jl", "types.jl"]
Filter = t -> !in(t, (GQLInterface.execute, GQLInterface.GQLResponse))
Public = false
```

## Output Fields

```@autodocs
Modules = [GQLInterface]
Pages   = ["output_fields.jl"]
Public = false
```

## Arguments

```@autodocs
Modules = [GQLInterface]
Pages   = ["args.jl"]
Public = false
```

## Variables

```@autodocs
Modules = [GQLInterface]
Pages   = ["variables.jl"]
Public = false
```

## Schema Utilities

```@autodocs
Modules = [GQLInterface]
Pages   = ["schema_utils.jl"]
Public = false
```

## Type Introspection

```@autodocs
Modules = [GQLInterface]
Pages   = ["type_construction.jl"]
Filter = t -> !in(t, (GQLInterface.AbstractIntrospectedStruct,))
Public = false
```

## Logging

```@autodocs
Modules = [GQLInterface]
Pages   = ["logging.jl"]
Public = false
```