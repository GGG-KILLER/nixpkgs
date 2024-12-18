{
  lib,
  stdenv,
  buildDotnetModule,
  fetchFromGitHub,
  autoPatchelfHook,
  wrapGAppsHook3,
  dotnetCorePackages,
  fontconfig,
  gtk3,
  icu,
  libkrb5,
  libunwind,
  openssl,
  xinput,
  xorg,
}:
buildDotnetModule (finalAttrs: {
  pname = "opentracker";
  version = "1.8.5";

  src = fetchFromGitHub {
    owner = "trippsc2";
    repo = "opentracker";
    rev = "refs/tags/${finalAttrs.version}";
    hash = "sha512-nWkPgVYdnBJibyJRdLPe3O3RioDPbzumSritRejmr4CeiPb7aUTON7HjivcV/GKor1guEYu+TJ+QxYrqO/eppg==";
  };

  patches = [
    ./dotnet-8-upgrade.patch
    ./remove-rids.patch
  ];

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  nugetDeps = ./deps.json;

  projectFile = "OpenTracker/OpenTracker.csproj";
  testProjectFile = "OpenTracker.UnitTests/OpenTracker.UnitTests.csproj";
  executables = [ "OpenTracker" ];

  doCheck = true;
  disabledTests = [
    "OpenTracker.UnitTests.Models.Nodes.Factories.SLightWorldConnectionFactoryTests.GetNodeConnections_ShouldReturnExpectedValue"
    "OpenTracker.UnitTests.Models.Sections.Factories.ItemSectionFactoryTests.GetItemSection_ShouldReturnExpected"
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc)
    fontconfig
    gtk3
    icu
    libkrb5
    libunwind
    openssl
  ];

  runtimeDeps =
    [
      gtk3
      openssl
      xinput
    ]
    ++ (with xorg; [
      libICE
      libSM
      libX11
      libXi
    ]);

  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libintl.so.8"
  ];

  meta = with lib; {
    description = "Tracking application for A Link to the Past Randomizer";
    homepage = "https://github.com/trippsc2/OpenTracker";
    sourceProvenance = with sourceTypes; [
      fromSource
      # deps
      binaryBytecode
      binaryNativeCode
    ];
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "OpenTracker";
    platforms = [ "x86_64-linux" ];
  };
})
