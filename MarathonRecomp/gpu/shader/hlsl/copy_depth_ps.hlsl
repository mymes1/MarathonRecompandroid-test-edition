#include "copy_common.hlsli"

#ifdef __spirv__
#define XENOS_RECOMP_DESCRIPTOR_ARRAY [1024]
#else
#define XENOS_RECOMP_DESCRIPTOR_ARRAY []
#endif

Texture2D<float> g_Texture2DDescriptorHeap XENOS_RECOMP_DESCRIPTOR_ARRAY : register(t0, space0);

float shaderMain(in float4 position : SV_Position) : SV_Depth
{
    return g_Texture2DDescriptorHeap[g_PushConstants.ResourceDescriptorIndex].Load(int3(position.xy, 0));
}
