#pragma once
#include <cmath>
#include <algorithm>
struct vec2; struct vec3; struct vec4;
struct vec2 { float x,y; vec2():x(0),y(0){} explicit vec2(float s):x(s),y(s){} vec2(float a,float b):x(a),y(b){} };
struct vec3 { float x,y,z; vec3():x(0),y(0),z(0){} explicit vec3(float s):x(s),y(s),z(s){} vec3(float a,float b,float c):x(a),y(b),z(c){} };
struct vec4 { float x,y,z,w; float &r=x,&g=y,&b=z,&a=w;
  vec4():x(0),y(0),z(0),w(0){} explicit vec4(float s):x(s),y(s),z(s),w(s){} vec4(float a_,float b_,float c_,float d):x(a_),y(b_),z(c_),w(d){}
  vec4(vec3 v,float d):x(v.x),y(v.y),z(v.z),w(d){}
  vec4(const vec4&o):x(o.x),y(o.y),z(o.z),w(o.w){} vec4& operator=(const vec4&o){x=o.x;y=o.y;z=o.z;w=o.w;return *this;}
  vec3 rgb() const {return vec3(x,y,z);} };
struct mat4 {}; struct sampler2D {};
extern vec4 g_tex; inline vec4 texture(sampler2D, vec2){return g_tex;}
#define BIN2(T,OP,...) 
#define VEC_OPS(T,F) \
 inline T operator+(T a,T b){return F(a,b,[](float p,float q){return p+q;});} \
 inline T operator-(T a,T b){return F(a,b,[](float p,float q){return p-q;});} \
 inline T operator*(T a,T b){return F(a,b,[](float p,float q){return p*q;});} \
 inline T operator/(T a,T b){return F(a,b,[](float p,float q){return p/q;});}
template<class L> vec2 f2(vec2 a,vec2 b,L l){return vec2(l(a.x,b.x),l(a.y,b.y));}
template<class L> vec3 f3(vec3 a,vec3 b,L l){return vec3(l(a.x,b.x),l(a.y,b.y),l(a.z,b.z));}
template<class L> vec4 f4(vec4 a,vec4 b,L l){return vec4(l(a.x,b.x),l(a.y,b.y),l(a.z,b.z),l(a.w,b.w));}
VEC_OPS(vec2,f2) VEC_OPS(vec3,f3) VEC_OPS(vec4,f4)
#define SC_OPS(T) \
 inline T operator+(T a,float s){return a+T(s);} inline T operator+(float s,T a){return T(s)+a;} \
 inline T operator-(T a,float s){return a-T(s);} inline T operator-(float s,T a){return T(s)-a;} \
 inline T operator*(T a,float s){return a*T(s);} inline T operator*(float s,T a){return T(s)*a;} \
 inline T operator/(T a,float s){return a/T(s);} inline T operator/(float s,T a){return T(s)/a;}
SC_OPS(vec2) SC_OPS(vec3) SC_OPS(vec4)
inline vec2 operator-(vec2 a){return vec2(-a.x,-a.y);}
inline vec2& operator+=(vec2&a,vec2 b){a=a+b;return a;}
inline float mix(float a,float b,float t){return a+(b-a)*t;}
inline vec2 mix(vec2 a,vec2 b,float t){return a*(1.0f-t)+b*t;}
inline vec3 mix(vec3 a,vec3 b,float t){return a*(1.0f-t)+b*t;}
inline vec4 mix(vec4 a,vec4 b,float t){return a*(1.0f-t)+b*t;}
inline float clamp(float v,float a,float b){return std::min(std::max(v,a),b);}
inline vec3 clamp(vec3 v,float a,float b){return vec3(clamp(v.x,a,b),clamp(v.y,a,b),clamp(v.z,a,b));}
inline float smoothstep(float a,float b,float x){float t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
inline float step(float e,float x){return x<e?0.f:1.f;}
inline float fract(float x){return x-std::floor(x);}
inline vec2 floor(vec2 v){return vec2(std::floor(v.x),std::floor(v.y));}
inline vec2 abs(vec2 v){return vec2(std::fabs(v.x),std::fabs(v.y));}
inline float abs(float v){return std::fabs(v);}
inline float min(float a,float b){return std::min(a,b);} inline float max(float a,float b){return std::max(a,b);}
inline vec2 min(vec2 a,vec2 b){return vec2(min(a.x,b.x),min(a.y,b.y));} inline vec2 max(vec2 a,vec2 b){return vec2(max(a.x,b.x),max(a.y,b.y));}
inline vec2 min(vec2 a,float b){return min(a,vec2(b));} inline vec2 max(vec2 a,float b){return max(a,vec2(b));}
inline float length(vec2 v){return std::sqrt(v.x*v.x+v.y*v.y);}
inline float dot(vec2 a,vec2 b){return a.x*b.x+a.y*b.y;} inline float dot(vec3 a,vec3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
inline float pow(float a,float b){return std::pow(a,b);} inline vec2 pow(vec2 a,vec2 b){return vec2(std::pow(a.x,b.x),std::pow(a.y,b.y));}
inline float exp2(float x){return std::exp2(x);} inline float log2(float x){return std::log2(x);}
inline float exp(float x){return std::exp(x);} inline float sin(float x){return std::sin(x);} inline float cos(float x){return std::cos(x);}
inline float atan(float y,float x){return std::atan2(y,x);} inline float sqrt(float x){return std::sqrt(x);}
inline float sign(float x){return x<0?-1.f:(x>0?1.f:0.f);} inline float floor(float x){return std::floor(x);}
inline float mod(float x,float y){return x-y*std::floor(x/y);}
inline float tanh(float x){return std::tanh(x);}
inline float abs(double v){return std::fabs((float)v);}
