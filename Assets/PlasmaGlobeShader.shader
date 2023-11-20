// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/PlasmaGlobeShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Zoom ("Zoom", Range(0, 5)) = 1.5
        
        _NumRays ("Rays Count", Int) = 13
        _RaysRange ("Rays Range", Range(0, 180)) = 1
        _RaysSize ("Rays Size", Range(0.5, 2)) = 1
        _HearthSize ("Hearth Size", Range(0, 1)) = 1

        _BackgroundColor ("Background Color", Color) = (0.0, 0.0, 0.0, 1)
        _BackgroundSphereColor ("Background Sphere Color", Color) = (0.0, 0.0, 0.0, 1)
        _BaseColor ("Base Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _RaysColor ("Rays Color", Color) = (1.0, 1.0, 1.0, 1.0)

        [Toggle] _RaysNoiseActived ("Rays Noise", Float) = 0
        _DispersionPercent ("Dispersion Percentage", Range(0, 1)) = 0.25
        _StartRaysPercent ("Start Rays Percentage", Range(0, 1)) = 1

        _Test ("Test", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            #define iMouse _MousePos

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float4 iMouse;

            sampler2D _MainTex;
            float4 _MainTex_ST;

            int _NumRays;
            float _RaysRange;
            float _RaysSize;
            float _HearthSize;

            float3 _BackgroundColor;
            float3 _BackgroundSphereColor;
            float3 _BaseColor;
            float3 _RaysColor;

            bool _RaysNoiseActived;
            float _DispersionPercent;
            float _StartRaysPercent;
            float _Zoom;

            float _Test;

            float3x3 m3 = float3x3(  0.00,  0.80,  0.60,
                                    -0.80,  0.36, -0.48,
                                    -0.60, -0.48,  0.64 );

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv.xy = (v.vertex.xy + 0.5);
                o.uv.z = (v.vertex.z + 0.5);
                return o;
            }

            float noise(in float3 x) 
            {
                float3 p = floor(x);
                float3 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);
        
                float2 uv = (((p.xy + float2(37.0, 17.0) * p.z) + f.xy) + 0.5) / 256.0;
                
                float2 rg = tex2Dlod(_MainTex, float4(uv.x, uv.y, 0, 0)).yx;
                return lerp(rg.x, rg.y, f.z);
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
                    x -= _Time.y * .65 * z;
                }

                return rz;
            }

            float hash(float n)
            {
                return frac(sin(n) * 43758.5453);
            }

            float2x2 mm2(in float a)
            {
                float c = cos(a);
                float s = sin(a);
    
                return float2x2(c, -s, s, c);
            }

            //Patron de rayos
            float3 path(in float i, in float d)
            {
                float3 en = float3(0., 0., 1.);
                float sns2 = sins(d + i * 0.5) * _DispersionPercent;
                float sns = sins(d + i * .6) * _DispersionPercent;

                en.xz = mul(en.xz, mm2((hash(i * 10.569) - .5) * 6.2 + sns2));
                en.xy = mul(en.xy, mm2((hash(i * 4.732) - .5) * 6.2 + sns));

                return en * _StartRaysPercent;
            }

            float segm(float3 p, float3 b)
            {
                float h = clamp(dot(p, b) / dot(b, b), 0., 1.);

                return length(p - b * h) * .5;
            }

            float2 map(float3 p, float i)
            {
                float lp = length(p);
                float3 en = path(i, lp);
    
                float hearthSizeMax = 0.25;
                float ins = smoothstep(hearthSizeMax * _HearthSize, 0.45, lp);
                float outs = .15 + smoothstep(0., .15, abs(lp - 1.));
                float id = ins * outs;
                p *= ins * outs;

                float raysSizeBase = 0.011;
                float rz = segm(p, en) - (raysSizeBase * _RaysSize);

                return float2(rz, id);
            }

            float march(in float3 ro, in float3 rd, in float startf, in float maxd, in float j)
            {
                float precis = 0.001;
                float h = 0.5;
                float d = startf;

                for (int i = 0; i < 25; i++)
                {
                    if (abs(h) < precis || d > maxd) break;

                    d += h * 1.2;
                    h = map(ro + rd * d, j).x;
                }

                return d;
            }

            //volumetric marching
            float3 vmarch(in float3 ro, in float3 rd, in float j, in float3 orig)
            {
                float3 p = ro;
                float2 r = (0.);
                float3 sum = (0.);
                float w = 0.;

                for (int i = 0; i < 15; i++)
                {
                    r = map(p, j);
                    p += rd * .03;

                    float lp = length(p);
                    //float3 col = sin(float3(1.05, 2.5, 1.52) * 3.94 + r.y) * .85 + 0.4;
                    float3 col = sin(_BaseColor + r.y) * cos(_RaysColor - r.y);

                    col.rgb *= smoothstep(.0, .015, -r.x);
                    col *= smoothstep(0.04, .2, abs(lp - 1.1));
                    col *= smoothstep(0.1, .34, lp);

                    sum += abs(col) * 5. * (1.2 - noise(lp * 2. + j * _NumRays + _Time.y * 5.) * 1.1) / (log(distance(p, orig) - 2.) + .75);
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

                if (h < 0.0)
                {
                    return (-1.);
                }
                else
                {
                    return float2((-b - sqrt(h)), (-b + sqrt(h)));
                }
            }

            float grid(float3 p)
            {
                return sin(p.x) * cos(p.y);
            }

            float flow(in float3 p)
            {
                float z = 2.;
                float rz = 0.;
                float3 bp = p;
    
                for (float i = 1.; i < 5.; i++)
                {
		            //movement
                    p += _Time.y * 0.25;
                    bp -= _Time.y * .3;
		
		            //displacement map
                    float3 gr = float3(grid(p * 3. - _Time.y * 1.), grid(p * 3.5 + 4. - _Time.y * 1.), grid(p * 4. + 4. - _Time.y * 1.));
                    p += gr * 0.15;
                    rz += (sin(noise(p) * 8.) * 0.5 + 0.5) / z;
		
		            //advection factor (.1 = billowing, .9 high advection)
                    p = lerp(bp, p, .7);
		
		            //scale and rotate
                    z *= 2.;
                    p = mul(p, 2.01);
                    p = mul(p, m3);
                    bp = mul(bp, 1.7);
                    bp = mul(bp, m3);
                }
                return rz;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 p = i.uv - 0.5;
                float2 um = iMouse.xy - .5;

                //camera
                float3 ro = float3(0., 0., 5.);
                float3 rd = normalize(float3(p * .7, -_Zoom));
    
                float2x2 mx = mm2(_Time.y * .4 + um.x * 6.);
                float2x2 my = mm2(_Time.y * 0.3 + um.y * 6.);
                
                ro.xy = mul(ro.xy, my);
                ro.xz = mul(ro.xz, mx);
                
                rd.xy = mul(rd.xy, my);
                rd.xz = mul(rd.xz, mx);

                float3 bro = ro;
                float3 brd = rd;

                float3 col = _BackgroundColor;

                //Rays
                for (int j = 0; j < _NumRays; j++)
                {
                    ro = bro;
                    rd = brd;

                    float2x2 mm = mm2((_Time.y * 0.1 + ((j + 1.) * 5.1)) * j * 0.25);
            
                    ro.xy = mul(ro.xy, mm);
                    ro.xz = mul(ro.xz, mm);
        
                    rd.xy = mul(rd.xy, mm);
                    rd.xz = mul(rd.xz, mm);

                    float rz = march(ro, rd, 2.5, 6., j);

                    if (rz >= 6.) continue; 

                    float3 pos = ro + mul(rz, rd);
                    col = max(col, vmarch(pos, rd, j, bro));
                }

                //Sphere
                ro = bro;
                rd = brd;
                float2 sph = iSphere2(ro, rd);

                if (sph.x > 0.)
                {
                    float3 pos = ro + rd * sph.x;
                    float3 pos2 = ro + rd * sph.y;
                    float3 rf = reflect(rd, pos);
                    float3 rf2 = reflect(rd, pos2);
                    float nz = (-log(abs(flow(rf * 1.2) - .01)));
                    float nz2 = (-log(abs(flow(rf2 * 1.2) - .01)));

                    //col += (0.1 * nz * nz * float3(0.12, 0.12, .5) + 0.05 * nz2 * nz2 * float3(0.55, 0.2, .55)) * 0.8;
                    col += nz * nz * _BackgroundSphereColor + 0.05 * nz2 * nz2;
                }

                return float4(col * 1.3, 1.0);
            }

            ENDCG
        }
    }
}