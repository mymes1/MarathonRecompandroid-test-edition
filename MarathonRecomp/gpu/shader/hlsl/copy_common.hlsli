#pragma once

#ifdef __spirv__
#define XENOS_RECOMP_DESCRIPTOR_ARRAY [1024]
#else
#define XENOS_RECOMP_DESCRIPTOR_ARRAY []
#endif

struct PushConstants
{
    uint ResourceDescriptorIndex;
};

[[vk::push_constant]] ConstantBuffer<PushConstants> g_PushConstants : register(b3, space4);
