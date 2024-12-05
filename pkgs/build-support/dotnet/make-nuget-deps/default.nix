{
  symlinkJoin,
  lib,
  fetchNupkg,
}:
lib.makeOverridable (
  {
    name,
    nugetDeps ? null,
    sourceFile ? null,
    installable ? false,
  }:
  let
    callNupkg = pkg: if lib.isDerivation pkg then pkg else fetchNupkg pkg;

    loadDeps =
      x:
      if x == null then
        [ ]
      else if lib.isDerivation x then
        [ x ]
      else if builtins.isList x then
        builtins.map callNupkg x
      else
        loadDeps (
          if builtins.isFunction x then
            x { fetchNuGet = args: fetchNupkg (args // { inherit installable; }); }
          else if lib.hasSuffix ".json" x then
            lib.importJSON x
          else
            import x
        );

    deps = if nugetDeps != null then loadDeps nugetDeps else loadDeps sourceFile;
  in
  (symlinkJoin {
    name = "${name}-nuget-deps";
    paths = deps;
  })
  // {
    inherit sourceFile;
  }
)
