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
  (symlinkJoin {
    name = "${name}-nuget-deps";
    paths =
      let
        loadDeps =
          if nugetDeps != null then
            nugetDeps
          else if lib.hasSuffix ".json" sourceFile then
            { fetchNuGet }: builtins.map fetchNuGet (lib.importJSON sourceFile)
          else
            assert (lib.isPath sourceFile);
            import sourceFile;
      in
      loadDeps {
        fetchNuGet = args: fetchNupkg (args // { inherit installable; });
      };
  })
  // {
    inherit sourceFile;
  }
)
