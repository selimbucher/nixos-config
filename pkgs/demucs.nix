# Demucs (Hybrid Transformer music source separation) — not in nixpkgs.
# Pure-Python app built from the PyPI sdist. Its two compiled deps that are
# missing from nixpkgs (lameenc, sphn) are pulled in as prebuilt manylinux
# wheels and autoPatchelf'd, which avoids a Rust/maturin build for sphn.
{ lib
, python3Packages
, fetchurl
, autoPatchelfHook
, stdenv
, zlib
, ffmpeg
}:

let
  py = python3Packages;

  # C extension bundling libmp3lame; self-contained, no numpy/torch ABI surface.
  lameenc = py.buildPythonPackage rec {
    pname = "lameenc";
    version = "1.8.4";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/21/ab/61087872800c15f91c5e50c5331b139c4b55b62cbb3fbd25aeb87052e752/lameenc-1.8.4-cp313-cp313-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-DltGqOTr891JWvwF/I782iTqwXs4bixgsNLnCNJmwVQ=";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    doCheck = false;
    pythonImportsCheck = [ "lameenc" ];
  };

  # Rust/pyo3 audio I/O library (kyutai). Prebuilt wheel avoids maturin.
  sphn = py.buildPythonPackage rec {
    pname = "sphn";
    version = "0.2.1";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/2b/d4/7953118678e8a8fe939d1bf18daa52a16baf9dadfe97bc62aa208fb3f57b/sphn-0.2.1-cp313-cp313-manylinux_2_24_x86_64.whl";
      hash = "sha256-iQPVgeC/k+/Xd+BC5BSjZMfqgE+YZGktOvZZnDFf8ZI=";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib zlib ];
    doCheck = false;
    pythonImportsCheck = [ "sphn" ];
  };
in
py.buildPythonApplication rec {
  pname = "demucs";
  version = "4.1.0";
  pyproject = true;

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/cd/0a/fe873fc9d9576de2b20fd6421857b189dee951b89305977f6c37416a8d42/demucs-4.1.0.tar.gz";
    hash = "sha256-2UxPfayIZZW2avQFwP0XVvoAwpcYPxzwIf0u7t7rZ7I=";
  };

  build-system = [ py.hatchling ];

  dependencies = (with py; [
    einops
    huggingface-hub
    julius
    pyyaml
    safetensors
    torch
    torchaudio # not strictly a runtime dep, included defensively — cheap, already in nixpkgs
    tqdm
  ]) ++ [ lameenc sphn ];

  # demucs shells out to ffmpeg to read/write non-wav audio formats.
  makeWrapperArgs = [ "--prefix PATH : ${lib.makeBinPath [ ffmpeg ]}" ];

  pythonImportsCheck = [ "demucs" "demucs.separate" ];
  doCheck = false; # real test downloads model weights from HuggingFace; not sandbox-safe

  meta = {
    description = "Music source separation in the waveform domain (Hybrid Transformer Demucs)";
    homepage = "https://github.com/adefossez/demucs";
    license = lib.licenses.mit;
    mainProgram = "demucs";
  };
}
