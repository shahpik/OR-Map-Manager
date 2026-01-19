# Public

```@contents
Pages = ["public.md"]
```

Documentation for GQLInterface's public interface.

## Client

```@docs
Client
full_introspection!
get_queries
get_mutations
get_subscriptions
```

## Operations

```@docs
query
mutate
open_subscription
GQLInterface.execute
GQLInterface.GQLResponse
GQLInterface.GQLEnum
GQLInterface.Alias
```

## Type Introspection

```@docs
introspect_object
get_introspected_type
list_all_introspected_objects
initialise_introspected_struct
create_introspected_struct
GQLInterface.AbstractIntrospectedStruct
```