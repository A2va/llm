-- set_xmakever("2.8.2")

set_allowedplats("windows", "linux", "macosx", "wasm")

add_rules("mode.release", "mode.debug", "mode.releasedbg", "mode.minsizerel")

option("accelerate", {default = is_plat("macosx"), description  = "Enable Accelerate framework"})
option("metal", {default = is_plat("macosx"), description  = "Enable Metal framework"})

option("clblast", {default = true, description  = "Enable OpenCL acceleration"})
option("openblas", {default = false, description  = "Enable OpenBLAS acceleration"})
option("cublas", {default = true, description  = "Enable CUDA acceleration"})

option("avx", {default = true, description  = "Enable avx support"})
option("avx2", {default = true, description  = "Enable avx2 support"})
option("avx512", {default = true, description  = "Enable avx512 support"})
option("fma", {default = true, description  = "Enable fma support"})
option("f16c", {default = true, description  = "Enable f16c support"})
option("sse", {default = true, description  = "Enable sse support"})

option("kquants", {default = true, description  = "Enable k quantization"})

-- function to callback a callback with a certain value an option is enabled
local function option_callback(option, value, callback) 
    if has_config(option) then
        callback(value)
    end
end

option_callback("clblast", "clblast", add_requires)
option_callback("openblas", "openblas", add_requires)
option_callback("cublas", "cuda", add_requires)

target("ggml")

    on_load(function (target)
        if has_config("metal") then
            -- HACK: patch ggml-metal.m so that it includes ggml-metal.metal, so that
            -- a runtime dependency is not necessary
            local data = io.readfile("llama-cpp/ggml-metal.metal")
            local needle = [[NSString * src  = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];]]
            io.replace("llama-cpp/ggml-metal.m", needle, format([[NSString * src  = @"%s";]], data), {plain = true})

            io.replace("llama-cpp/ggml-metal.m", [[fprintf(stderr,]], [[metal_printf(]],  {plain = true})
            io.replace("llama-cpp/ggml-metal.m", [[#define metal_printf(...) fprintf(stderr, __VA_ARGS__)]], [[#define metal_printf(...) fprintf(stderr, __VA_ARGS__)]],  {plain = true})
        end
    end)

    set_kind("static")
    set_languages("cxx11","c11")

    add_headerfiles("llama-cpp/ggml.h")
    add_files("llama-cpp/ggml.c")
    if os.exists("llama-cpp/ggml-alloc.h") then
        add_files("llama-cpp/ggml-alloc.c")
        add_headerfiles("llama-cpp/ggml-alloc.h")
    end

    if is_plat("linux", "macosx") then 
        add_cflags("-pthread")
    end 

    -- GPU Acceleration
    if has_config("accelerate") then
        add_frameworks("Accelerate")
		add_defines("GGML_USE_ACCELERATE")
    end

    if has_config("metal") then 
        add_frameworks("MetalKit", "Foundation", "Metal", "MetalPerformanceShaders")
        add_files("llama-cpp/ggml-metal.m", "llama-cpp/ggml-metal.metal")
        add_headerfiles("llama-cpp/ggml-metal.h")
        add_defines("GGML_USE_METAL")
		if is_mode("release") then
			add_defines("GGML_METAL_NDEBUG")
		end
    end

	if has_config("openblas") then
		add_packages("openblas")
		add_defines("GGML_USE_OPENBLAS")
	end

    if has_config("clblast") then 
        add_packages("clblast")
        add_files("llama-cpp/ggml-opencl.cpp")
        add_headerfiles("llama-cpp/ggml-opencl.h")
		add_defines("GGML_USE_CLBLAST")
    end

    if has_config("cublas") then 
        add_packages("cuda")
        add_files("llama-cpp/ggml-cuda.cu")
        add_headerfiles("llama-cpp/ggml-cuda.h")
		add_defines("GGML_USE_CUBLAS")
    end

    if has_config("kquants") then 
        add_files("llama-cpp/k_quants.c")
        add_headerfiles("llama-cpp/k_quants.h")
        add_defines("GGML_USE_K_QUANTS")
    end

    if is_arch("x86_64", "x64", "i386", "x86") then
        option_callback("avx", "avx", add_vectorexts)
        option_callback("avx2", "avx2", add_vectorexts)
        option_callback("sse", "sse3", add_vectorexts)
        option_callback("fma", "fma", add_vectorexts)
        -- option_callback("avx512", "avx512", add_vectorexts)

        if not is_plat("windows") and has_config("f16c") then
            add_cxflags("-mf16c")
        end
    elseif is_arch("arm.*") then
        add_vectorexts("neon")
    end

    if is_mode("release") then 
        add_defines("NDEBUG")
    end

    if is_plat("windows") then 
        add_defines("WIN32", "WINDOWS")
    end