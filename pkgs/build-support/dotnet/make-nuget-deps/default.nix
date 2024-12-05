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
        fetchNupkgWithInstallable = args: fetchNupkg (args // { inherit installable; });
      in
      if lib.hasSuffix ".json" nugetDeps then
        builtins.map fetchNupkgWithInstallable (lib.importJSON nugetDeps)
      else
        assert (lib.isFunction nugetDeps);
        nugetDeps { fetchNuGet = fetchNupkgWithInstallable; };
  })
  // {
    inherit sourceFile;
  }
)
