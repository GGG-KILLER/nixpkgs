{
  lib,
  stdenvNoCC,
  fetchgit,
  fetchFromGitHub,
  fetchurl,
  boringssl,
  nghttp2,
  ngtcp2,
  curl,
  installShellFiles,
}:
let
  version = "1.0.0rc2";
  curl-impersonate-src = fetchFromGitHub {
    owner = "lexiforest";
    repo = "curl-impersonate";
    tag = "v${version}";
    hash = "sha256-YmxFJAEhpSRCG4UDZbfMQm5r4RbOkhzIVh8/nmvWl54=";

    postFetch = ''
      # Fix patch to not refer to the dev version.
      substituteInPlace "$out"/patches/curl.patch --replace-fail 8.13.0-DEV 8.13.0

      # Remove lines related to scripts/singleuse.pl
      sed -i -E '4029,4040d' "$out"/patches/curl.patch
    '';
  };

  boringssl-commit = "673e61fc215b178a90c0e67858bbf162c8158993"; # BORING_SSL_COMMIT in Makefile.in
  # nix-prefetch-git https://boringssl.googlesource.com/boringssl $BORING_SSL_COMMIT
  boringssl-hash = "sha256-8Dl6Aol33o2FYID3oIw9grB0jY9VJnnnhmiNdyycTlU=";

  curl-version = "8.13.0"; # CURL_VERSION in Makefile.in
  # nix store prefetch-file https://curl.haxx.se/download/curl-$CURL_VERSION.tar.xz
  curl-hash = "sha256-Sgk5eaPC0C3i+8AFSaMncQB/LngDLG+qXs0vep4VICU=";

  ###
  # MAINTAINERS: Change things above this, nothing should need changing below unless build changes have
  #              been made to the Makefile.in or any of the components of curl-impersonate.
  ###

  # In Makefile.in, the host OS is defined like this.
  cmakeSystemName =
    if stdenvNoCC.hostPlatform.isLinux then
      "Linux"
    else if stdenvNoCC.hostPlatform.isDarwin then
      "Darwin"
    else
      "Linux";

  commonCmakeFlags = [
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    (lib.cmakeFeature "CMAKE_POSITION_INDEPENDENT_CODE" "on")
    (lib.cmakeFeature "CMAKE_SYSTEM_NAME" cmakeSystemName)
  ];

  # Patch BoringSSL to be equal to Chrome's.
  # Also set correct cmake flags (unsure if needed).
  patched-boringssl = boringssl.overrideAttrs (old: {
    src = fetchgit {
      url = "https://boringssl.googlesource.com/boringssl";
      rev = boringssl-commit;
      hash = boringssl-hash;
    };

    patches = old.patches or [ ] ++ [
      "${curl-impersonate-src}/patches/boringssl.patch"
    ];

    # Required for curl to build, since it searches for OpenSSL stuff in the same dir as the includes.
    postInstall = ''
      mv "$out"/lib "$dev"/lib
      cp $src/* "$dev"/.
    '';

    cmakeFlags = old.cmakeFlags or [ ] ++ commonCmakeFlags;
  });

  # Replace SSL library with BoringSSL as well as brotli and nghttp3.
  # Also set correct cmake flags (unsure if needed).
  patched-ngtcp2 =
    (ngtcp2.override {
      quictls = patched-boringssl;
    }).overrideAttrs
      (old: {
        cmakeFlags = old.cmakeFlags ++ [
          (lib.cmakeBool "ENABLE_LIB_ONLY" true)
          (lib.cmakeBool "ENABLE_OPENSSL" false)
          (lib.cmakeBool "ENABLE_BORINGSSL" true)
          "-DCMAKE_LIBRARY_PATH=${lib.getBin patched-boringssl}/lib"
          "-DBORINGSSL_LIBRARIES=ssl;crypto;pthread"
          "-DBORINGSSL_INCLUDE_DIR=${lib.getDev patched-boringssl}/include"
        ];
      });

  # Remove all extraneous dependencies.
  # Set correct configure flags (unsure if required).
  patched-nghttp2 =
    (nghttp2.override {
      enableApp = false;
      enableGetAssets = false;
      enableHpack = false;
      enableHttp3 = false;
      enableJemalloc = false;
      enablePython = false;

      # Technically, these aren't used, but they're kept here in case that changes in the future.
      ngtcp2 = patched-ngtcp2;
      openssl = patched-boringssl;
      quictls = patched-boringssl;
      curl = curl-impersonate;
    }).overrideAttrs
      (old: {
        configureFlags = old.configureFlags or [ ] ++ [
          "--with-pic"
          "--enable-lib-only"
          "--disable-python-bindings"
        ];
      });

  # Set only the needed features.
  # Replace dependencies by patched ones.
  #
  curl-impersonate =
    (curl.override {
      brotliSupport = true;
      http2Support = true;
      nghttp2 = patched-nghttp2;
      http3Support = true;
      ngtcp2 = patched-ngtcp2;
      quictls = patched-boringssl;
      websocketSupport = true;
      opensslSupport = true;
      openssl = patched-boringssl;
      zlibSupport = true;
      zstdSupport = true;
      scpSupport = false;
    }).overrideAttrs
      (old: {
        pname = "curl-impersonate";
        inherit version;

        src = fetchurl {
          urls = [
            "https://curl.haxx.se/download/curl-${curl-version}.tar.xz"
            "https://github.com/curl/curl/releases/download/curl-${
              builtins.replaceStrings [ "." ] [ "_" ] curl-version
            }/curl-${curl-version}.tar.xz"
          ];
          hash = curl-hash;
        };

        nativeBuildInputs = old.nativeBuildInputs ++ [ installShellFiles ];

        patches = old.patches or [ ] ++ [
          "${curl-impersonate-src}/patches/curl.patch"
        ];

        configureFlags = old.configureFlags or [ ] ++ [
          "--with-nghttp2=${lib.getDev patched-nghttp2}"
          "--enable-ech"
          "--enable-ipv6"
          "USE_CURL_SSLKEYLOGFILE=true"
        ];

        postInstall =
          old.postInstall or ""
          + ''
            # Rename curl binary and install other scripts
            mv "$outputBin"/curl "$outputBin"/curl-impersonate
            install "${curl-impersonate-src}"/bin/curl_* "$outputBin"/

            patchShebangs "$outputBin"
          ''
          + lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
            # Build and install completions for each curl binary

            # Patch in correct binary name and alias it to all scripts
            perl scripts/completion.pl --curl "$outputBin"/curl-impersonate --shell zsh >curl-impersonate.zsh
            substituteInPlace curl-impersonate.zsh \
              --replace-fail \
                '#compdef curl' \
                "#compdef curl-impersonate$(find "$outputBin" -name 'curl_*' -printf ' %f=curl-impersonate')"

            perl scripts/completion.pl --curl "$outputBin"/curl-impersonate --shell fish >curl-impersonate.fish
            substituteInPlace curl-impersonate.fish \
              --replace-fail \
                '--command curl' \
                "--command curl-impersonate$(find "$outputBin" -name 'curl_*' -printf ' --command %f')"

            # Install zsh and fish completions
            installShellCompletion curl-impersonate.{zsh,fish}
          '';

        passthru = {
          boringssl = patched-boringssl;
          tests = {
            # Don't inherit other tests since they use curl, not curl-impersonate.
            withCheck = old.passthru.withCheck;
            # Also add our own tests
          };
        };

        meta = old.meta // {
          changelog = "https://github.com/lexiforest/curl-impersonate/releases/tag/v${version}";
          description = "Special build of curl that can impersonate Chrome & Firefox";
          homepage = "https://github.com/lexiforest/curl-impersonate";
          license = with lib.licenses; [
            curl
            mit
          ];
          maintainers = with lib.maintainers; [ ggg ];
          platforms = lib.platforms.unix;
          mainProgram = "curl-impersonate";
        };
      });
in
curl-impersonate
