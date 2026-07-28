# Basic Pitch (Spotify audio-to-MIDI converter) — not in nixpkgs.
# Built from the PyPI sdist. Upstream pins tensorflow<2.15.1 on Linux, which is
# far older than nixpkgs' tensorflow (2.21). We instead run the bundled ONNX
# model via onnxruntime: with no tensorflow/coreml/tflite importable, basic-pitch
# auto-selects its ONNX backend (the nmp.onnx model ships in the sdist).
{ lib
, python3Packages
, fetchurl
}:

let
  py = python3Packages;

  # nixpkgs' mir-eval fails its matplotlib image-comparison tests (test_display.py)
  # under newer matplotlib — pixel-diff baselines, not a correctness issue. Skip
  # that one file; the numeric test suite still runs. The check pushd's into
  # tests/, so the path is relative to that dir.
  mir-eval = py.mir-eval.overridePythonAttrs (old: {
    disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [ "test_display.py" ];
  });

  pretty-midi = py.buildPythonPackage rec {
    pname = "pretty-midi";
    version = "0.2.11";
    pyproject = true;
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/12/4f/5b18643f947ca2a97e25c3615740e4ead2b833fcd0b1d5d4262ea688519d/pretty_midi-0.2.11.tar.gz";
      hash = "sha256-3agdZD9xoOkYQ6hkSzEsA4Ajfx5j1cYYgiV4XI1YzGc=";
    };
    build-system = [ py.setuptools ];
    dependencies = with py; [ numpy mido six importlib-resources ];
    doCheck = false;
    pythonImportsCheck = [ "pretty_midi" ];
  };
in
py.buildPythonApplication rec {
  pname = "basic-pitch";
  version = "0.4.0";
  pyproject = true;

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/d3/68/384dcaa2493497581ef7a0f18c76ce35afa26ea8a8d703f4761bdae632e6/basic_pitch-0.4.0.tar.gz";
    hash = "sha256-b0isS5CcmQ/VlGBiITegO4V8gpux8+ZccXCNpXaraOU=";
  };

  build-system = with py; [ setuptools wheel cython ];

  dependencies = (with py; [
    librosa
    mir-eval
    numpy
    resampy
    scikit-learn
    scipy
    typing-extensions
    onnxruntime # inference backend; replaces upstream's tensorflow requirement
  ]) ++ [ pretty-midi ];

  # tensorflow pin is unsatisfiable against nixpkgs; the other two are marker-gated
  # to platforms/pythons we don't target. Runtime uses onnxruntime instead.
  pythonRemoveDeps = [ "tensorflow" "tflite-runtime" "coremltools" ];
  # nixpkgs resampy (0.4.3) is one patch above upstream's `<0.4.3` cap.
  pythonRelaxDeps = [ "resampy" ];

  pythonImportsCheck = [ "basic_pitch" "basic_pitch.inference" ];
  doCheck = false;

  meta = {
    description = "Lightweight audio-to-MIDI converter with pitch-bend detection";
    homepage = "https://github.com/spotify/basic-pitch";
    license = lib.licenses.asl20;
    mainProgram = "basic-pitch";
  };
}
