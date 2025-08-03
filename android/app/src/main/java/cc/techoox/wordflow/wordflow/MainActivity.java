package cc.techoox.wordflow.wordflow;

import android.content.Intent;
import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // 1. 强制启用软件渲染，完全绕过GPU
        getIntent().putExtra("enable-software-rendering", true);
        getIntent().putExtra("disable-gpu", true);
        getIntent().putExtra("disable-gpu-sandbox", true);
        
        // 2. 彻底禁用硬件加速
        getWindow().clearFlags(android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
        
        // 3. 强制使用软件渲染层
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.HONEYCOMB) {
            getWindow().getDecorView().setLayerType(android.view.View.LAYER_TYPE_SOFTWARE, null);
        }
        
        // 4. 禁用所有可能的硬件加速特性
        try {
            // 强制禁用OpenGL
            System.setProperty("flutter.disable_opengl", "true");
            // 强制使用CPU渲染
            System.setProperty("flutter.force_cpu_rendering", "true");
            // 禁用GPU纹理
            System.setProperty("flutter.disable_gpu_textures", "true");
        } catch (Exception e) {
            // 忽略设置失败
        }
        
        super.onCreate(savedInstanceState);
    }
}
