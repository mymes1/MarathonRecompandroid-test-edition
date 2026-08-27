#include "imgui_common.h"

static std::vector<std::unique_ptr<ImGuiCallbackData>> g_callbackData;
static uint32_t g_callbackDataIndex = 0;

ImGuiCallbackData* AddImGuiCallbackTo(ImDrawList* drawList, ImGuiCallback callback)
{
    if (drawList == nullptr)
        return nullptr;

    if (g_callbackDataIndex >= g_callbackData.size())
        g_callbackData.emplace_back(std::make_unique<ImGuiCallbackData>());

    auto& callbackData = g_callbackData[g_callbackDataIndex];
    ++g_callbackDataIndex;

    drawList->AddCallback(reinterpret_cast<ImDrawCallback>(callback), callbackData.get());

    return callbackData.get();
}

ImGuiCallbackData* AddImGuiCallback(ImGuiCallback callback)
{
    return AddImGuiCallbackTo(ImGui::GetBackgroundDrawList(), callback);
}

void ResetImGuiCallbacks()
{
    g_callbackDataIndex = 0;
}
