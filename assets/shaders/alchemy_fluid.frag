#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform sampler2D uField;
out vec4 fragColor;
// Continuous, domain-warped waves avoid discontinuous corner hashes on
// mobile shader backends. Keep detail smooth independently of atlas cells.
float noise(vec2 p){
 vec2 q=p+vec2(sin(dot(p,vec2(.83,.57))),sin(dot(p,vec2(-.61,.91))+2.4))*.55;
 return .5+(sin(dot(q,vec2(1.73,1.21)))
           +sin(dot(q,vec2(-1.37,2.09))+1.7)
           +sin(dot(q,vec2(2.41,-.93))+4.1))/6.;
}
float cloud(vec2 p){return noise(p)*.57+noise(p*2.03+7.1)*.28+noise(p*4.01)*.15;}
// Cubic B-spline reconstruction is C2-continuous across cell boundaries.
// Derivatives use the same basis as density, rather than finite differences
// between independently interpolated samples. Atlas halves never bleed.
vec4 cubic(float t){
 float t2=t*t,t3=t2*t;
 return vec4((1.-t)*(1.-t)*(1.-t),3.*t3-6.*t2+4.,-3.*t3+3.*t2+3.*t+1.,t3)/6.;
}
vec4 cubicDerivative(float t){
 return vec4(-.5*(1.-t)*(1.-t),1.5*t*t-2.*t,-1.5*t*t+t+.5,.5*t*t);
}
vec3 reconstruct(vec2 uv,float layer,out vec3 dx,out vec3 dy){
 vec2 pixel=uv*vec2(160,240)-.5,base=floor(pixel),f=fract(pixel);
 vec4 wx=cubic(f.x),wy=cubic(f.y),gx=cubicDerivative(f.x),gy=cubicDerivative(f.y);
 vec3 value=vec3(0.);dx=vec3(0.);dy=vec3(0.);
 for(int y=0;y<4;y++){
   for(int x=0;x<4;x++){
     vec2 cell=clamp(base+vec2(float(x)-1.,float(y)-1.),vec2(0.),vec2(159,239));
     vec2 at=vec2((cell.x+.5+layer*160.)/640.,(cell.y+.5)/240.);
     vec3 sampleValue=texture(uField,at).rgb;
     value+=sampleValue*wx[x]*wy[y];
     dx+=sampleValue*gx[x]*wy[y];
     dy+=sampleValue*wx[x]*gy[y];
   }
 }
 return value;
}
void main(){
 vec2 uv=FlutterFragCoord().xy/uSize;
 vec2 p=vec2(uv.x*uSize.x/uSize.y,uv.y);
 vec3 ax,ay,dx,dy,gx,gy,ex,ey;
 vec3 base=reconstruct(uv,0.,ax,ay);
 vec3 field=reconstruct(uv,1.,dx,dy);
 vec3 gas=reconstruct(uv,2.,gx,gy);
 vec3 emission=reconstruct(uv,3.,ex,ey);
 float density=field.r;
 vec2 grad=vec2(dx.r,dy.r);
 vec3 col=mix(vec3(.012,.023,.035),vec3(.028,.060,.075),exp(-length((uv-vec2(.5,.75))*vec2(2.,1.5))*2.));
 float detail=cloud(p*vec2(20,28)+vec2(sin(uTime*.3),uTime*.4));
 float mist=field.g;
 vec3 gasColor=gas/max(mist,.001);
 float opacity=1.-exp(-mist*(1.1+detail));
 col=mix(col,gasColor*.48,opacity);
 float edgeWidth=max((abs(grad.x)*160./uSize.x+abs(grad.y)*240./uSize.y)*.8,.045);
 float surface=smoothstep(.38-edgeWidth,.38+edgeWidth,density);
 vec3 normal=normalize(vec3(-grad*3.5,.35));
 vec3 light=normalize(vec3(-.5,-.7,.7));
 float roughness=clamp(field.b/max(density,.001),0.,1.);
 float fresnel=pow(1.-normal.z,2.);
 float spec=pow(max(dot(reflect(-light,normal),vec3(0,0,1)),0.),mix(50.,6.,roughness));
 vec3 albedo=base/max(density,.001);
 float depth=clamp(uv.y*.7+density*.4,0.,1.);
 vec3 liquid=albedo*mix(1.1,.48,depth)*(.7+.3*max(dot(normal,light),0.));
 float caustic=pow(.5+.5*sin(uv.x*38.+sin(uv.y*24.+uTime*.6)*2.+sin(uv.x*19.-uTime*.4)),14.);
 liquid+=vec3(.045,.12,.14)*caustic*(1.-roughness)*.35;
 liquid+=vec3(.20,.42,.47)*fresnel*(1.-roughness)*.8;
 liquid+=vec3(.65,.83,.9)*spec*(1.-roughness)*.7;
 liquid+=albedo*(detail-.5)*roughness*.15;
 col=mix(col,liquid,surface);
 // Smooth emission is part of the same reconstructed material field.
 // Bounded continuous detail avoids the previous mobile corner-hash seams.
 float molten=density*clamp((emission.r-emission.b)*4.,0.,1.);
 float crust=smoothstep(.42,.67,cloud(p*vec2(18,23)+vec2(0,uTime*.045)));
 col=mix(col,vec3(.027,.021,.028),crust*molten*.9);
 float glow=(1.+detail*.5)*(1.-crust*molten*.94);
 col+=emission*glow*2.2;
 float vignette=1.-.38*length((uv-.5)*1.3);
 col*=vignette;
 col=vec3(1.)-exp(-col*1.35);
 col=pow(col,vec3(.88));
 fragColor=vec4(col,1.);
}
