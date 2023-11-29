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
        _SpeedRays ("Speed Rays", Range(0, 5)) = 1
        _SpeedSphere ("Speed Rays", Range(0, 5)) = 1

        _BackgroundColor ("Background Color", Color) = (0.0, 0.0, 0.0, 1)
        _BackgroundSphereColor ("Background Sphere Color", Color) = (0.0, 0.0, 0.0, 1)
        _BaseColor ("Base Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _RaysColor ("Rays Color", Color) = (1.0, 1.0, 1.0, 1.0)

        [Toggle] _RaysNoiseActived ("Rays Noise", Float) = 0
        _DispersionPercent ("Dispersion Percentage", Range(0, 1)) = 0.25

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
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

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

            float _MouseX;
            float _MouseY;
            bool _EnableCast;

            float _PosX;
            float _PosY;
            bool _EnableMoveCamera;

            sampler2D _MainTex;
            float4 _MainTex_ST;

            int _NumRays;
            float _RaysRange;
            float _RaysSize;
            float _HearthSize;
            float _SpeedRays;
            float _SpeedSphere;

            float3 _BackgroundColor;
            float3 _BackgroundSphereColor;
            float3 _BaseColor;
            float3 _RaysColor;

            bool _RaysNoiseActived;
            float _DispersionPercent;
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

            //ray's pattern
            float3 path(in float i, in float d, in float3 hit)
            {
                float3 en = float3(0., 0., 1.);
                float sns2 = sins(d + i * .5) * _DispersionPercent;
                float sns = sins(d + i * .6) * _DispersionPercent;
    
                if (dot(hit, hit) > 0.)
                {
                    // mouse interaction
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
                float3 b = float3(0., 0., 0.);
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
                    if (abs(h) < precis || d > maxd)
                    {
                        break;
                    }

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

                if (h < .0)
                {
                    return (-1.);
                }
                
                return float2((-b - sqrt(h)), (-b + sqrt(h)));
}

            float grid(float3 p)
            {
                return sin(p.x) * cos(p.y);
            }

            //billowing effect flow
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
                float2 p = i.uv - .5;
                float2 um = float2(_MouseX, _MouseY) - .5;
                float2 pos = float2(_PosX, _PosY);

                //camera
                float3 ro = float3(0., 0., 5.);
                float3 rd = normalize(float3(p * .7, -_Zoom));
    
                float ss = _Time.y * _SpeedSphere;
                float sr = _Time.y * _SpeedRays;
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

                    float rz = march(ro, rd, 2.5, 6., j, float3(0., 0., 0.));

                    if (rz >= 6.) continue; 

                    float3 pos = ro + mul(rz, rd);
                    col = max(col, vmarch(pos, rd, j, bro, float3(0., 0., 0.)));
                }
    
                //mouse interaction
                if (_EnableCast)
                {
                    float3 hit = float3(0., 0., 0.);
                    float3 rdm = normalize(float3(um * .7, -1.5));
                    rdm.xz = mul(rdm.xz, mx);
                    rdm.xy = mul(rdm.xy, my);
    
                    // Compute intersection point between the surface of the sphere
                    // and the ray casted by the mouse
                    float2 res = iSphere2(bro, rdm);
                    if (res.x > 0.)
                    {
                        hit = bro + res.x * rdm;
                    }
    
                    // Cast a final ray for the light path of the mouse
                    if (dot(hit, hit) != 0.)
                    {
                        float j = _NumRays + 1.;
                        ro = bro;
                        rd = brd;
                        float2x2 mm = mm2((_Time.y * 0.1 + ((j + 1.) * 5.1)) * j * 0.25);
        
                        float rz = march(ro, rd, 2.5, 6., j, hit);
                        if (rz < 6.)
                        {
                            float3 pos = ro + rz * rd;
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
                    float nz = (-log(abs(flow(rf * 1.2) - .01)));
                    float nz2 = (-log(abs(flow(rf2 * 1.2) - .01)));

                    col += nz * nz * _BackgroundSphereColor + 0.05 * nz2 * nz2;
                }

                return float4(col, 1.0);
            }

            ENDCG
        }
    }
}