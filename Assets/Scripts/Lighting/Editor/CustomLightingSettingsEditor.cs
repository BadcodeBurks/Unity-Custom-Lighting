using System;
using UnityEditor;
using UnityEngine;

namespace Lighting.Editor
{
    [CustomEditor(typeof(CustomLightingSettings))]
    public class CustomLightingSettingsEditor : UnityEditor.Editor
    {
        private CustomLightingSettings _target;
        private void OnEnable()
        {
            _target = (CustomLightingSettings) target;
            _target.GetIDs();
            _target.CheckKeywords();
            _target.UpdateLightingSettings();
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();
            EditorGUILayout.BeginVertical();
            EditorGUI.BeginChangeCheck();
            _target.useStepDistance = EditorGUILayout.Toggle("Use Step Distance", _target.useStepDistance);
            _target.diffuseMode = (CustomLightingSettings.DiffuseModes)EditorGUILayout.EnumPopup("Use LUT", _target.diffuseMode);
            if (EditorGUI.EndChangeCheck())
            {
                _target.UpdateKeywords();
            }
            EditorGUI.BeginChangeCheck();
            switch(_target.diffuseMode)
            {
                case CustomLightingSettings.DiffuseModes.Lambert:
                    break;
                case CustomLightingSettings.DiffuseModes.Lut:
                    _target.gradient = EditorGUILayout.GradientField("Lighting Gradient", _target.gradient);
                    int lutSegmentInput = EditorGUILayout.IntField("LUT Segment Count", _target.lutSegmentCount);
                    _target.lutSegmentCount = Mathf.Max(2, lutSegmentInput);
                    break;
                case CustomLightingSettings.DiffuseModes.Ramp:
                    _target.rampRange.x = EditorGUILayout.Slider("Ramp Range Min", _target.rampRange.x, 0, 1);
                    _target.rampRange.y = Mathf.Max(EditorGUILayout.Slider("Ramp Range Max", _target.rampRange.y, 0, 1), _target.rampRange.x);
                    break;
            }
            _target.ambientColor = EditorGUILayout.ColorField("Ambient Color", _target.ambientColor);
            if (EditorGUI.EndChangeCheck())
            {
                EditorUtility.SetDirty(target);
                _target.UpdateLightingSettings();
            }
            EditorGUILayout.EndHorizontal();
        }
    }
}