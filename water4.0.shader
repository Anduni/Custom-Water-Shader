Shader "custom/water4.0"
{
  Properties 
  {
  	_Refract ("Refraction Normal", 2D) = "" {}
  	_WaterLight("Water Light", Color) = (0.2,0.8,0.9,1)
  	_WaterDark ("Water Dark", Color) = (0.2,0.8,0.9,1)
  	_HighColor ("Highlight Color", Color) = (1,1,1,1)
  	_High ("Highlight", Range(0,10)) = 5
  	_Depth ("Fog Depth", Range(1,5)) = 2
  	_DepthMax ("Maximum Fog Opacity", Range(0,1)) = 0.9
  	_Distort ("Distortion", Range(0,1)) = 1
  	_WaveShift ("Wave Shift", Range(0,3)) = 1
  }

  SubShader 
  {
    Tags { "Queue" = "Transparent" }
	GrabPass { "_background" }
    Pass 
    { 	
    	Cull Off
      	CGPROGRAM
      	#pragma target 3.0
      	#pragma vertex vert
      	#pragma fragment frag
      	#include "UnityCG.cginc"

		sampler2D _CameraDepthTexture;
      	sampler2D _background;
      	sampler2D _Refract;
      	float4 _HighColor;
      	float4 _WaterLight;
      	float4 _WaterDark;
      	float _Depth;
      	float _DepthMax;
      	float _Distort;
      	float _WaveShift;
      	float _High;

      	struct appdata {
      		float4 vertex : POSITION;
      		float2 uv : TEXCOORD0;
      	};
   	
      	struct v2f 
      	{
        	float4 pos : SV_POSITION;
        	float4 screenpos : TEXCOORD1;
        	float2 uv : TEXCOORD0;
        	float3 viewdir : FLOAT;
      	};
       
      	v2f vert(appdata v)
      	{         
        	v2f o;
        	o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
        	o.screenpos = ComputeScreenPos(o.pos);
        	o.uv = v.uv;

        	// calculating viewdirection on vertex
        	o.viewdir = normalize(WorldSpaceViewDir(v.vertex));

        	return o;
      	}

      	fixed4 frag(v2f i) : COLOR 
      	{
      		// wave shift
      		float2 waveshift = float2(_WaveShift, 0) * _Time;

			// calculating refraction from normals
			float3 n1 = UnpackNormal(tex2D(_Refract, i.uv + waveshift));
			float3 n2 = UnpackNormal(tex2D(_Refract, i.uv - waveshift));
			float3 normals = (n1 + n2) /2;
			float2 refr = normals.xy * 0.2 * _Distort;

			// calculating fresnel from lightdirection and normal reflection
			float3 reflective = reflect(_WorldSpaceLightPos0, normals);
			float fresnel = -dot(i.viewdir, reflective)/2 +0.5;
		
			// screenspace coordinates with offset
			float4 screen = float4(i.screenpos.xy + refr, i.screenpos.zw);

			// calculating depth with offset for frag and scene
			float sceneZ = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(screen)));
			float fragZ = screen.z;

			// masking out the refraction for objects above water surface
			float mask = step(fragZ, sceneZ);
			float2 refrmasked = refr * mask;

			// screenspace coordinates with masked offset
			float4 screen_masked = float4(i.screenpos.xy + refrmasked, i.screenpos.zw);

			// calculating depth with masked offset for scene
            float sceneZ_masked = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(screen_masked)));

			// difference between fragz and scenez
            float depth = (sceneZ_masked - fragZ) / _Depth; 
            if (depth > _DepthMax) depth = _DepthMax;


			// adding masked refraction offset
			half4 background = tex2Dproj(_background, UNITY_PROJ_COORD(screen_masked));

			half4 watercolor = lerp(_WaterDark, _WaterLight, fresnel);

			// adding depth
            half4 waterdepth = lerp(background, watercolor, depth);

            // adding highlights
            half4 water = lerp(waterdepth, _HighColor, pow(fresnel, 10-_High)*_High);

            return water;
      	}
      	ENDCG
    	}
  	}
}