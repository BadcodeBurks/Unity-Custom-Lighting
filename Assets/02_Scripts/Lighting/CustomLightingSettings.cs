using System;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[CreateAssetMenu(fileName = "CustomLightingSettings", menuName = "Burk/Lighting/CustomLightingSettings", order = 0)]
public class CustomLightingSettings : ScriptableObject {
    public enum DiffuseModes{
        Lambert,
        Lut,
        Ramp,
    }

    public bool useStepDistance;
    public DiffuseModes diffuseMode;
    public Gradient gradient;
    public int lutSegmentCount;
    public Color ambientColor;
    public Vector2 rampRange;
    public float RimDistance;
    private Texture2D _lightLut;
    
    private int _ambientColorID;
    private int _lightLutID;
    private int _lightRampID;
    private int _rimDistanceID;
    private GlobalKeyword _useLutForDiffuse;
    private GlobalKeyword _useRampForDiffuse;
    private GlobalKeyword _useStepDistance;

    private void Awake()
    {
        GetIDs();
        CheckKeywords();
        UpdateLightingSettings();
    }

    public void CheckKeywords()
    {
        _useLutForDiffuse = GlobalKeyword.Create("_USE_LUT_FOR_DIFFUSE");
        _useRampForDiffuse = GlobalKeyword.Create("_USE_RAMP_FOR_DIFFUSE");
        _useStepDistance = GlobalKeyword.Create("_USE_STEP_DISTANCE");
        UpdateKeywords();
    }
    
    public void GetIDs(){
        _ambientColorID = Shader.PropertyToID("_AmbientColor");
        _lightLutID = Shader.PropertyToID("_LightLut");
        _lightRampID = Shader.PropertyToID("_DiffuseRamp");
        _rimDistanceID = Shader.PropertyToID("_RimDistance");
    }

    private void GenerateLut(){
        if (lutSegmentCount == 0)
        {
            lutSegmentCount = 1;
        }
        _lightLut = new Texture2D(lutSegmentCount,1)
        {
            filterMode = FilterMode.Point,
            wrapMode = TextureWrapMode.Clamp
        };
        for (int i = 0; i < lutSegmentCount; i++){
            float t = i / (lutSegmentCount - 1f);
            Color c = gradient.Evaluate(t);
            c.a = 1;
            _lightLut.SetPixel(i,0,c);
        }
        _lightLut.Apply();
    }
    
    public void UpdateLightingSettings(){
        GenerateLut();
        Shader.SetGlobalTexture(_lightLutID, _lightLut);
        Shader.SetGlobalVector(_lightRampID, rampRange);
        Shader.SetGlobalFloat(_rimDistanceID, RimDistance);
        RenderSettings.ambientLight = ambientColor;
    }

    public void UpdateKeywords()
    {
        switch (diffuseMode)
        {
            case DiffuseModes.Lambert:
                Shader.DisableKeyword(_useLutForDiffuse);
                Shader.DisableKeyword(_useRampForDiffuse);
                break;
            case DiffuseModes.Lut:
                Shader.EnableKeyword(_useLutForDiffuse);
                Shader.DisableKeyword(_useRampForDiffuse);
                break;
            case DiffuseModes.Ramp:
                Shader.DisableKeyword(_useLutForDiffuse);
                Shader.EnableKeyword(_useRampForDiffuse);
                break;
        }
        Shader.SetKeyword(_useStepDistance, useStepDistance);
    }
}