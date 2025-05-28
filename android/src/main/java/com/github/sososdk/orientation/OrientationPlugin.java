package com.github.sososdk.orientation;

import android.app.Activity;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

/**
 * OrientationPlugin
 */
public class OrientationPlugin implements FlutterPlugin, ActivityAware {
    private @Nullable FlutterPluginBinding flutterPluginBinding;
    private @Nullable MethodCallHandlerImpl methodCallHandler;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        flutterPluginBinding = binding;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        flutterPluginBinding = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        methodCallHandler = new MethodCallHandlerImpl();
        Activity activity = binding.getActivity();
        if (flutterPluginBinding != null) {
            methodCallHandler.startListening(activity, flutterPluginBinding.getBinaryMessenger());
        }
    }

    @Override
    public void onDetachedFromActivity() {
        if (methodCallHandler != null) {
            methodCallHandler.stopListening();
            methodCallHandler = null;
        }
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }
}
