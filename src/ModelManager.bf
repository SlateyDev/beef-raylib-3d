using System;
using System.Collections;
using System.Diagnostics;
using RaylibBeef;

class ModelManager {
    private Dictionary<String, Model> mModels = new Dictionary<String, Model>() ~ {
        for (var item in _) {
            Raylib.UnloadModel(item.value);
        }
        DeleteDictionaryAndKeys!(_);
    }

    public Model Get(String modelPath) {
        Model model;
        var ok = mModels.TryGetValue(modelPath, out model);
        if (!ok) {
            model = Raylib.LoadModel(modelPath);
            mModels.Add(new String(modelPath), model);
        }
        return model;
    }

    public void UpdateModelShaders(Shader shader) {
        for (let model in mModels) {
            for (int i = 0; i < model.value.materialCount; i++) {
                model.value.materials[i].shader = shader;
            }
        }
    }
}