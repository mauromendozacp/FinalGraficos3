Shader "Unlit/PlasmaGlobeShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Zoom ("Zoom", Range(0, 5)) = 1.5
        
        _NumRays ("Rays Count", Int) = 13
        _RaysSize ("Rays Size", Range(0.5, 2)) = 1
        _HearthSize ("Hearth Size", Range(0, 1)) = 1
        _SpeedRays ("Speed Rays", Range(0, 5)) = 1
        _SpeedSphere ("Speed Sphere", Range(0, 5)) = 1
        _DispersionPercent ("Dispersion Percentage", Range(0, 1)) = 0.25
        [Toggle] _RaysNoiseActived ("Rays Noise", Float) = 0

        _BackgroundColor ("Background Color", Color) = (0.0, 0.0, 0.0, 1)
        _BackgroundSphereColor1 ("Background Sphere Color 1", Color) = (0.0, 0.0, 0.0, 1)
        _BackgroundSphereColor2 ("Background Sphere Color 2", Color) = (0.0, 0.0, 0.0, 1)
        _BaseColor ("Base Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _RaysColor ("Rays Color", Color) = (1.0, 1.0, 1.0, 1.0)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

            #define iResolution _ScreenParams
            #define iTime _Time.y

            float _MouseX;
            float _MouseY;
            bool _EnableCast;

            float _PosX;
            float _PosY;
            bool _EnableMoveCamera;

            sampler2D _MainTex;

            int _NumRays;
            float _RaysSize;
            float _HearthSize;
            float _SpeedRays;
            float _SpeedSphere;

            bool _RaysNoiseActived;
            float _DispersionPercent;
            float _Zoom;

            float3 _BackgroundColor;
            float3 _BackgroundSphereColor1;
            float3 _BackgroundSphereColor2;
            float3 _BaseColor;
            float3 _RaysColor;

            float3x3 m3 = float3x3( 0.00,  0.80,  0.60,
                                   -0.80,  0.36, -0.48,
                                   -0.60, -0.48,  0.64);

            v2f vert (appdata v)
            {
                v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv * iResolution.xy;
				return o;
            }

            float hash(float n)
            {
                return frac(sin(n) * 43758.5453);
            }

            float2 hash(float2 p)
            {
                p = frac(sin(p * float2(37.0, 41.0)) * 43758.5453123);
                return frac((p.x + p.y) * p);
            }

            float noise(in float x)
            {
                return tex2Dlod(_MainTex, float4(x * .01, 1., 0., 0.)).x;
            }

            float noise(float3 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
    
                float2 v00 = hash(i);
                float2 v10 = hash(i + float2(1, 0));
                float2 v01 = hash(i + float2(0, 1));
                float2 v11 = hash(i + float2(1, 1));
    
                float x = smoothstep(0.0, 1.0, f.x);
                float y = smoothstep(0.0, 1.0, f.y);

                float2 v0 = lerp(v00, v10, x);
                float2 v1 = lerp(v01, v11, x);

                return lerp(v0, v1, y);
            }

            //flow's background sphere
            float flow(in float3 p, in float t)
            {
                float z = 2.;
                float rz = 0.;
                float3 bp = p;
                for (float i = 1.; i < 5.; i++)
                {
                    p += iTime * 1.75;
                    rz += (sin(noise(p + t * 0.8) * 6.) * 0.5 + 0.5) / z;
                    p = lerp(bp, p, 0.6);
                    z *= 2.;
                    p *= 2.01;
                    p = mul(p, m3);
                }
                return rz;
            }

            float sins(in float x)
            {
                float rz = 0.;
                float z = 2.;

                int noiseCurr = 3;
                int noiseMax = 25;

                if (_RaysNoiseActived)
                {
                    noiseCurr = noiseMax;
                }

                for (int i = 0; i < noiseCurr; i++)
                {
                    rz += abs(frac(x * 1.4) - 0.5) / z;
                    x *= 1.3;
                    z *= 1.15;
                    x -= (sin(iTime / 3.1415)) + iTime * .65 * z;
                }

                return rz;
            }

            float2x2 mm2(in float a)
            {
                float c = cos(a);
                float s = sin(a);
    
                return float2x2(c, -s, s, c);
            }

            //ray's pattern
            float3 path(in float i, in float d, in float3 hit)
            {
                float3 en = float3(0., 0., 1.);
                float sns2 = sins(d + i * .5) * _DispersionPercent;
                float sns = sins(d + i * .6) * _DispersionPercent;
    
                // mouse interaction
                if (dot(hit, hit) > 0.)
                {
                    hit.xz = mul(hit.xz, mm2(sns2 * .5));
                    hit.xy = mul(hit.xy, mm2(sns * .3));
                    return hit;
                }

                en.xz = mul(en.xz, mm2((hash(i * 10.569) - .5) * 6.2 + sns2));
                en.xy = mul(en.xy, mm2((hash(i * 4.732) - .5) * 6.2 + sns));

                return en;
            }

            //ray's segmentation
            float segm(float3 p, float3 a)
            {
                float3 b = (0.);
                float3 pa = p - a;
                float3 ba = b - a;
                float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);

                return length(pa - ba * h) * .5;
            }

            //sizes of hearth and rays
            float2 map(float3 p, float i, in float3 hit)
            {
                float lp = length(p);
                float3 en = path(i, lp, hit);
    
                float hearthSizeMax = 0.25;
                float ins = smoothstep(hearthSizeMax * _HearthSize, 0.46, lp);
                float outs = .15 + smoothstep(0., .15, abs(lp - 1.));
                p *= ins * outs;
                float id = ins * outs;

                float raysSizeBase = 0.011;
                float rz = segm(p, en) - (raysSizeBase * _RaysSize);

                return float2(rz, id);
            }

            //marching
            float march(in float3 ro, in float3 rd, in float startf, in float maxd, in float j, in float3 hit)
            {
                float precis = 0.001;
                float h = 0.5;
                float d = startf;

                for (int i = 0; i < 35; i++)
                {
                    if (abs(h) < precis || d > maxd) break;

                    d += h * 1.2;
                    h = map(ro + rd * d, j, hit).x;
                }

                return d;
            }

            //volumetric marching
            float3 vmarch(in float3 ro, in float3 rd, in float j, in float3 orig, in float3 hit)
            {
                float3 p = ro;
                float2 r = (0.);
                float3 sum = (0.);
                float w = 0.;

                for (int i = 0; i < 19; i++)
                {
                    r = map(p, j, hit);
                    p += rd * .03;

                    float lp = length(p);
                    float3 col = sin(_BaseColor + r.y) * cos(_RaysColor - r.y);

                    col.rgb *= smoothstep(.0, .015, -r.x);
                    col *= smoothstep(0.04, .2, abs(lp - 1.1));
                    col *= smoothstep(0.1, .34, lp);

                    sum += abs(col) * 5. * (1.2 - noise(lp * 2. + j * _NumRays + iTime * 5.) * 1.1) / (log(distance(p, orig) - 2.) + .75);
                }

                return sum;
            }

            //returns both collision dists of unit sphere
            float2 iSphere2(in float3 ro, in float3 rd)
            {
                float3 oc = ro;
                float b = dot(oc, rd);
                float c = dot(oc, oc) - 1.;
                float h = b * b - c;

                if (h < .0)
                {
                    return (-1.);
                }
                
                return float2((-b - sqrt(h)), (-b + sqrt(h)));
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv / iResolution.xy - .5;
                uv.x *= iResolution.x / iResolution.y;
    
                float2 um = float2(_MouseX, _MouseY);
                float2 pos = float2(_PosX, _PosY);

                //camera
                float3 ro = float3(0., 0., 5.);
                float3 rd = normalize(float3(uv * .7, -_Zoom));
    
                //speeds
                float ss = iTime * _SpeedSphere;
                float sr = iTime * _SpeedRays;
                if (_EnableMoveCamera)
                {
                    ss = .0;
                    sr = .0;
                }
    
                float2x2 mx = mm2(ss * .4 + pos.x);
                float2x2 my = mm2(ss * .3 + pos.y);
                
                ro.xy = mul(ro.xy, my);
                ro.xz = mul(ro.xz, mx);
                
                rd.xy = mul(rd.xy, my);
                rd.xz = mul(rd.xz, mx);

                float3 bro = ro;
                float3 brd = rd;

                float3 col = _BackgroundColor;

                //rays
                for (int j = 0; j < _NumRays; j++)
                {
                    ro = bro;
                    rd = brd;

                    float2x2 mm = mm2((sr * 0.1 + ((j + 1.) * 5.1)) * j * 0.25);
            
                    ro.xy = mul(ro.xy, mm);
                    ro.xz = mul(ro.xz, mm);
        
                    rd.xy = mul(rd.xy, mm);
                    rd.xz = mul(rd.xz, mm);

                    float rz = march(ro, rd, 2.5, 6., j, (0.));

                    if (rz >= 6.) continue; 

                    float3 pos = ro + mul(rz, rd);
                    col = max(col, vmarch(pos, rd, j, bro, (0.)));
                }
    
                //mouse interaction
                if (_EnableCast)
                {
                    float3 hit = (0.);
                    float3 rdm = normalize(float3(um * .05, -_Zoom));
                    rdm.xy = mul(rdm.xy, my);
                    rdm.xz = mul(rdm.xz, mx);
    
                    //mouse collision with sphere
                    float2 res = iSphere2(bro, rdm);
                    if (res.x > 0.)
                    {
                        hit = bro + res.x * rdm;
                    }
        
                    if (dot(hit, hit) != 0.)
                    {
                        float j = _NumRays;
                        ro = bro;
                        rd = brd;
                        float2x2 mm = mm2((sr * 0.1 + ((j + 1.) * 5.1)) * j * 0.25);
            
                        float rz = march(ro, rd, 2.5, 6., j, hit);

                        if (rz < 6.)
                        {
                            float3 pos = ro + mul(rz, rd);
                            col = max(col, vmarch(pos, rd, j, bro, hit));
                        }
                    }
                }
    
                //sphere
                ro = bro;
                rd = brd;
    
                float2 sph = iSphere2(ro, rd);
                if (sph.x > 0.)
                {
                    float3 pos = ro + rd * sph.x;
                    float3 pos2 = ro + rd * sph.y;
                    float3 rf = reflect(rd, pos);
                    float3 rf2 = reflect(rd, pos2);
                    float nz = (-log(abs(flow(rf * 1.2, iTime) - .1)));
                    float nz2 = (-log(abs(flow(rf2 * 1.2, -iTime) - .1)));

                    col += (0.1 * nz * nz * _BackgroundSphereColor1 + 0.05 * nz2 * nz2 * _BackgroundSphereColor2) * 0.8;
                }

                return float4(col, 1.0);
            }

            ENDCG
        }
    }
}