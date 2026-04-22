import os
import tensorflow as tf
import subprocess
import sys

def convert_onnx_to_tflite(onnx_path="./deployment/mamba_ecg.onnx", tf_model_dir="./deployment/tf_model", tflite_path="./deployment/mamba_ecg.tflite"):
    print("Converting ONNX to TensorFlow SavedModel using onnx2tf...")

    # 1. Convert ONNX to TensorFlow using command line with the auto-generated JSON fix
    json_path = os.path.join(tf_model_dir, "mamba_ecg_auto.json")
    try:
        if os.path.exists(json_path):
            # Use the auto-generated JSON fix
            cmd = f'"{sys.executable}" -m onnx2tf -i {onnx_path} -o {tf_model_dir} -prf {json_path}'
            print(f"Using auto-generated JSON fix: {json_path}")
        else:
            # Fallback to basic conversion
            cmd = f'"{sys.executable}" -m onnx2tf -i {onnx_path} -o {tf_model_dir}'

        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            print(f"[ERROR] ONNX to TF conversion failed: {result.stderr}")
            return
        print(f"[SUCCESS] Successfully converted to TensorFlow SavedModel at {tf_model_dir}")
    except subprocess.TimeoutExpired:
        print("[ERROR] ONNX to TF conversion timed out")
        return
    except Exception as e:
        print(f"[ERROR] ONNX to TF conversion failed: {e}")
        return

    print("Applying Quantization and converting to TFLite format for Wearable Devices...")

    # 2. Convert TF SavedModel to TFLite with FP16 Edge Optimization
    converter = tf.lite.TFLiteConverter.from_saved_model(tf_model_dir)

    # Applying Float16 Quantization to reduce model size rapidly and speed up inference by 2x
    # while retaining nearly 100% of precision.
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]


if __name__ == '__main__':
    convert_onnx_to_tflite()
