use std::env;
use std::path::Path;

use xmake::Config;

// By default, this crate will attempt to compile ggml with the features of your host system if
// the host and target are the same. If they are not, it will turn off auto-feature-detection,
// and you will need to manually specify target features through target-features.
fn main() {
    verify_state();

    println!("cargo:rerun-if-changed=llama-cpp");

    let target = "ggml";
    let mut config = Config::new("llama-cpp");
    // Set mode and target name
    config.target(target);

    // Acceleration option
    config.option("metal", cfg_metal().to_string());
    config.option("clblast", cfg_clblast().to_string());
    config.option("cublas", cfg_cublas().to_string());
    config.option("openblas", "false"); // Disable openblas for now

    let features = x86::Features::get();

    config.option("avx", features.avx.to_string());
    config.option("avx2", features.avx2.to_string());
    config.option("sse", features.sse3.to_string());
    config.option("f16c", features.f16c.to_string());
    config.option("fma", features.fma.to_string());

    let dst = config.build();
    println!("cargo:rustc-link-search=native={}", dst.display());
    println!("cargo:rustc-link-lib=static={target}");
}

/// Verify the state of the repo to catch common newbie mistakes.
fn verify_state() {
    assert!(
        Path::new("llama-cpp/ggml.c").exists(),
        "Could not find llama-cpp/ggml.c. Try running `git submodule update --init`"
    );
}

fn cfg_cublas() -> bool {
    !cfg!(target_os = "macos") && cfg!(feature = "cublas")
}

fn cfg_clblast() -> bool {
    !cfg!(target_os = "macos") && cfg!(feature = "clblast")
}

fn cfg_metal() -> bool {
    cfg!(feature = "metal")
}

fn get_supported_target_features() -> std::collections::HashSet<String> {
    env::var("CARGO_CFG_TARGET_FEATURE")
        .unwrap()
        .split(',')
        .map(ToString::to_string)
        .collect()
}

mod x86 {
    #[allow(clippy::struct_excessive_bools)]
    #[derive(Clone, Debug, PartialEq, Eq)]
    pub struct Features {
        pub fma: bool,
        pub avx: bool,
        pub avx2: bool,
        pub f16c: bool,
        pub sse3: bool,
    }
    impl Features {
        pub fn get() -> Self {
            #[cfg(any(target_arch = "x86", target_arch = "x86_64"))]
            if std::env::var("HOST") == std::env::var("TARGET") {
                return Self::get_host();
            }

            Self::get_target()
        }

        #[cfg(any(target_arch = "x86", target_arch = "x86_64"))]
        pub fn get_host() -> Self {
            Self {
                fma: std::is_x86_feature_detected!("fma"),
                avx: std::is_x86_feature_detected!("avx"),
                avx2: std::is_x86_feature_detected!("avx2"),
                f16c: std::is_x86_feature_detected!("f16c"),
                sse3: std::is_x86_feature_detected!("sse3"),
            }
        }

        pub fn get_target() -> Self {
            let features = crate::get_supported_target_features();
            Self {
                fma: features.contains("fma"),
                avx: features.contains("avx"),
                avx2: features.contains("avx2"),
                f16c: features.contains("f16c"),
                sse3: features.contains("sse3"),
            }
        }
    }
}
