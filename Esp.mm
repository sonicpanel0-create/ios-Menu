// HMOOD__TG@i_8_f
 

 
#import "Engine.h"
#include "esp.h"
#include "menu.h"
#include "imgui.h"
#include "imgui_internal.h"
#include "font_awesome_5.h"
#include <cmath>
#include <cfloat>
#include <cstdio>
#include <string>
#include <vector>
#include <atomic>
#include <mutex>
#include <chrono>
#include <algorithm>
#include <cstring>
#include <utility>

using namespace SDK;

extern ImFont* mainFont;
extern ImFont* cyberMenuFont;
extern ASTExtraPlayerCharacter* g_LocalPlayer;
extern ASTExtraPlayerController* g_PlayerController;
extern float ESPMaxDistance;
extern float AlertRadius;
extern float globalHpAlphaF;
extern float strokeIntensity;
extern ImColor bgColor;
extern float Cross;
extern bool textBorder;
extern bool Enable;
extern int IsStyle;
extern ImU32 COLOR_Distance;

namespace imgui {
    extern bool ESP,HideBot,Health,Line,Name,TeamID,Distance,EnemyCount,Boxes;
    extern bool Weapon,Bone,GameInfo,Alert360,EnemyAiming;
    extern bool Items,Lootbox,Vehicle;
}
namespace Settings {
    namespace Aimbot {
        extern bool Tick;
        namespace SilentAimSettings {
            extern bool EnableFov,AimingLine;
        }
    }
}

bool WorldToScreenBone(const FVector& WorldLocation,FVector2D* Out);
 
#define W2S(w, s) UGameplayStatics::ProjectWorldToScreen(g_PlayerController, w, false, s)

static ImVec2 espProjectionScale(.5f, .5f);

struct Color255 {
    uint8_t r, g, b, a;
};


 
 
 
  
Color255 realVisibleColor   = {0, 255, 0, 255};  
Color255 realInvisibleColor = {255, 0, 0, 255}; 
Color255 botVisibleColor    = {0, 255, 0, 255}; 
Color255 botInvisibleColor  = {255, 255, 255, 255}; 

static ImVec4 visibleColor   = ImVec4(0.f, 1.f, 0.f, 1.f); 
        static ImVec4 unvisibleColor = ImVec4(1.f, 0.f, 0.f, 1.f); 
 float lineThickness = 1.5f;

struct ColorRGB { int r, g, b; };

const ColorRGB palette1[7] = {
    {200, 185, 40}, {100, 150, 70}, {60, 165, 105}, {75, 110, 150},
    {80, 60, 140},  {135, 60, 130}, {140, 70, 60}
};
const ColorRGB palette2[7] = {
    {185, 180, 70}, {100, 190, 80}, {70, 160, 100}, {150, 190, 225},
    {150, 100, 220}, {150, 50, 160}, {200, 80, 80}
};

ImU32 TeamID_Color;
ImU32 TeamID_Color2;


// HMOOD__TG@i_8_f
void teamColor(int teamNumber, float alpha1, float alpha2) {
    if (teamNumber <= 0) teamNumber = 1;
    int index = (teamNumber - 1) % 7;
    TeamID_Color  = IM_COL32(palette1[index].r, palette1[index].g, palette1[index].b, (int)alpha1);
    TeamID_Color2 = IM_COL32(palette2[index].r, palette2[index].g, palette2[index].b, (int)alpha2);
}

// HMOOD__TG@i_8_f
static float VectorLength(const FVector &Vec) {
    return sqrtf(Vec.X * Vec.X + Vec.Y * Vec.Y + Vec.Z * Vec.Z);
}

// HMOOD__TG@i_8_f
static FVector NormalizeVector(const FVector &Vec) {
    float Length = VectorLength(Vec);
    if (Length == 0.0f)
        return FVector{0, 0, 0};

    return FVector{
        Vec.X / Length,
        Vec.Y / Length,
        Vec.Z / Length
    };
}

// HMOOD__TG@i_8_f
static float DotProduct(const FVector &Vec1, const FVector &Vec2) {
    return (Vec1.X * Vec2.X + Vec1.Y * Vec2.Y + Vec1.Z * Vec2.Z);
}

// HMOOD__TG@i_8_f
bool bIsAimingAtLocalPlayer(ASTExtraPlayerCharacter* Player) {
    if (!Player || !g_LocalPlayer)
        return false;

    static float AngleSensitivity = 20.f;

    FVector localHead = GetBoneLocationByName(g_LocalPlayer, "Head");
    FVector enemyHead = GetBoneLocationByName(Player, "Head");

    FVector Direction = localHead - enemyHead;
    FVector Forward = Player->GetActorForwardVector();

    float Angle = acosf(
        DotProduct(Forward, NormalizeVector(Direction))
    ) * (180.0f / M_PI);

    return Angle <= AngleSensitivity;
}

// HMOOD__TG@i_8_f
static float HealthCardScale() {
    return ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f) * ImClamp(globalHpAlphaF, .5f, 5.f);
}

static void DrawEspTextStroke(ImDrawList* draw, ImFont* font, float fontSize,
                              ImVec2 position, ImU32 color, const char* text) {
    if (!draw || !font || !text) return;
    const float width = ImClamp(strokeIntensity, .5f, 5.f);
    const ImU32 stroke = ImGui::ColorConvertFloat4ToU32(bgColor.Value);
    const ImVec2 offsets[] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1},
                             {-.7071f, -.7071f}, {.7071f, -.7071f},
                             {-.7071f, .7071f}, {.7071f, .7071f}};
    if (stroke & IM_COL32_A_MASK)
        for (const auto& offset : offsets)
            draw->AddText(font, fontSize, ImVec2(position.x + offset.x * width,
                                               position.y + offset.y * width), stroke, text);
    draw->AddText(font, fontSize, position, color, text);
}

// HMOOD__TG@i_8_f
static const char* WorldItemCategory(int id) {
    if (id >= 101001 && id <= 101999) return "AR";
    if (id >= 102001 && id <= 102999) return "SMG";
    if (id >= 103001 && id <= 103999) return "Sniper";
    if (id >= 104001 && id <= 104999) return "Shotgun";
    if (id >= 105001 && id <= 105999) return "LMG";
    if (id >= 106001 && id <= 106999) return "Pistol";
    if (id >= 107001 && id <= 108999) return "Melee";
    if (id >= 203001 && id <= 203999) return "Scope";
    if (id >= 201001 && id <= 205999) return "Attach";
    if (id >= 301001 && id <= 307999) return "Ammo";
    if (id >= 501001 && id <= 503999) return "Armor";
    if (id >= 601001 && id <= 601999) return "Med";
    if (id >= 602001 && id <= 602999) return "Throwable";
    return "Other";
}

static ImU32 WorldItemColor(const char* cat) {
    if (!strcmp(cat, "AR"))        return IM_COL32(0, 225, 233, 255);
    if (!strcmp(cat, "SMG"))       return IM_COL32(255, 150,  50, 255);
    if (!strcmp(cat, "Sniper"))    return IM_COL32(193, 42, 255, 255);
    if (!strcmp(cat, "Shotgun"))   return IM_COL32(200, 120, 255, 255);
    if (!strcmp(cat, "LMG"))       return IM_COL32(255, 200,  40, 255);
    if (!strcmp(cat, "Pistol"))    return IM_COL32(180, 180, 180, 255);
    if (!strcmp(cat, "Scope"))     return IM_COL32( 60, 200, 255, 255);
    if (!strcmp(cat, "Armor"))     return IM_COL32( 90, 160, 255, 255);
    if (!strcmp(cat, "Med"))       return IM_COL32( 60, 255, 160, 255);
    if (!strcmp(cat, "Throwable")) return IM_COL32(255, 255,  90, 255);
    if (!strcmp(cat, "Ammo"))      return IM_COL32(160, 160, 160, 255);
    if (!strcmp(cat, "Attach"))    return IM_COL32(150, 200, 150, 255);
    return IM_COL32(220, 220, 220, 255);
}

static const char* WorldItemName(int id) {
    switch (id) {

        case 101001: return "AKM";        case 101002: return "M16A4";   case 101003: return "SCAR-L";
        case 101004: return "M416";       case 101005: return "Groza";   case 101006: return "AUG";
        case 101007: return "QBZ";        case 101008: return "M762";    case 101009: return "Mk47";
        case 101010: return "G36C";       case 101012: return "HoneyBadger"; case 101100: return "FAMAS";
        case 101101: return "AN-94";      case 101102: return "ACE32";

        case 102001: return "UZI";        case 102002: return "UMP9";    case 102003: return "Vector";
        case 102004: return "Tommy";      case 102005: return "Bizon";   case 102007: return "MP5K";
        case 102008: return "JS9";        case 102105: return "P90";

        case 103001: return "Kar98k";     case 103002: return "M24";     case 103003: return "AWM";
        case 103004: return "SKS";        case 103005: return "VSS";     case 103006: return "Mini-14";
        case 103007: return "Mk14";       case 103008: return "Win94";   case 103009: return "SLR";
        case 103010: return "QBU";        case 103011: return "Mosin";   case 103012: return "AMR";
        case 103100: return "MK12";       case 103102: return "DSR-1";   case 103103: return "M1Garand";

        case 104001: return "S686";       case 104002: return "S1897";   case 104003: return "S12K";
        case 104004: return "DP-12";      case 104101: return "M1014";   case 104102: return "Neostead";

        case 105001: return "M249";       case 105002: return "DP-28";   case 105010: return "MG3";

        case 106001: return "P92";        case 106002: return "P1911";   case 106003: return "R1895";
        case 106004: return "P18C";       case 106005: return "R45";     case 106006: return "Sawed-Off";
        case 106008: return "Skorpion";   case 106010: return "DEagle";  case 106011: return "MP7";

        case 107001: return "Crossbow";   case 108001: return "Machete"; case 108004: return "Pan";
        case 108005: return "Dagger";

        case 203001: return "Holo";       case 203002: return "RedDot";  case 203003: return "2x";
        case 203004: return "4x";         case 203005: return "8x";      case 203014: return "3x";
        case 203015: return "6x";         case 203018: return "RMR";

        case 301001: return "9mm";        case 302001: return "7.62mm";  case 303001: return "5.56mm";
        case 304001: return "12Gauge";    case 305001: return ".45ACP";  case 306001: return ".300Mag";

        case 602001: return "Stun";       case 602002: return "Smoke";   case 602003: return "Molotov";
        case 602004: return "Frag";

        case 601001: return "Energy";     case 601002: return "Syringe"; case 601003: return "Pills";
        case 601004: return "First Aid"; case 601005: return "Bandage"; case 601006: return "Med Kit";

        case 501001: return "Bag1"; case 501002: return "Bag2"; case 501006: return "Bag3";
        case 502001: return "Helmet1"; case 502002: return "Helmet2"; case 502003: return "Helmet3";
        case 503001: return "Vest1"; case 503002: return "Vest2"; case 503003: return "Vest3";
        default: break;
    }
    
    
    
    static char s_unknownItem[24];
    snprintf(s_unknownItem, sizeof(s_unknownItem), "Item %d", id);
    return s_unknownItem;
}

// HMOOD__TG@i_8_f
namespace {
    enum WorldFeature : unsigned { WorldItems = 1, WorldLootbox = 2, WorldVehicle = 4 };
    struct WorldMarker {
        FVector position{};
        int itemID = 0;
        float healthRatio = -1.f, fuelRatio = -1.f;
        unsigned feature = 0;
        std::string name;
        const char* icon = ICON_FA_CUBE;
        ImU32 color = IM_COL32(220, 220, 220, 255);
    };
    struct WorldFrame {
        FVector playerPosition{}, cameraPosition{};
        FRotator cameraRotation{};
        float fov = 0.f;
        double capturedAt = 0.;
        std::vector<WorldMarker> items, lootboxes, vehicles;
    };
    std::atomic<unsigned> worldRequests{0};
    std::atomic<float> worldRange{300.f};
    std::mutex worldFrameMutex;
    WorldFrame worldFrame;

    static double WorldTime() {
        return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
    }
    static bool WorldVectorValid(const FVector& p) {
        return std::isfinite(p.X) && std::isfinite(p.Y) && std::isfinite(p.Z) &&
               fabsf(p.X) < 1.e9f && fabsf(p.Y) < 1.e9f && fabsf(p.Z) < 1.e9f;
    }
    static float WorldDistanceSquared(const FVector& a, const FVector& b) {
        const float x = a.X - b.X, y = a.Y - b.Y, z = a.Z - b.Z;
        return x * x + y * y + z * z;
    }
    static const char* WorldItemIcon(const char* category) {
        if (!strcmp(category, "Med")) return ICON_FA_FIRST_AID;
        if (!strcmp(category, "Armor")) return ICON_FA_SHIELD_ALT;
        if (!strcmp(category, "Scope")) return ICON_FA_BULLSEYE;
        if (!strcmp(category, "Throwable")) return ICON_FA_BOMB;
        if (!strcmp(category, "Ammo")) return ICON_FA_WEIGHT;
        if (!strcmp(category, "Attach")) return ICON_FA_LAYER_GROUP;
        if (!strcmp(category, "Melee")) return ICON_FA_CROSSHAIRS;
        return ICON_FA_CUBE;
    }
    static void CaptureVehicleDetails(ASTExtraVehicleBase* vehicle, WorldMarker& marker) {
        marker.name = GetVehicleName(vehicle);
        if (auto* common = vehicle->VehicleCommon) {
            if (std::isfinite(common->HPMax) && common->HPMax > 0.f && std::isfinite(common->HP))
                marker.healthRatio = ImClamp(common->HP / common->HPMax, 0.f, 1.f);
            if (std::isfinite(common->FuelMax) && common->FuelMax > 0.f && std::isfinite(common->Fuel))
                marker.fuelRatio = ImClamp(common->Fuel / common->FuelMax, 0.f, 1.f);
        }
    }
    template <class T, class Describe>
    static void CaptureWorldActors(UWorld* world, const FVector& playerPosition, float maxDistance,
                                    size_t limit, unsigned feature, Describe describe,
                                    std::vector<WorldMarker>& markers) {
        markers.clear();
        auto* gameplay = (UGameplayStatics*)UGameplayStatics::StaticClass();
        if (!gameplay) return;
        TArray<AActor*> actors{};
        gameplay->GetAllActorsOfClass((UObject*)world, T::StaticClass(), &actors);
        const float maxSquared = maxDistance * maxDistance * 10000.f;
        for (int i = 0; i < actors.Num(); ++i) {
            AActor* actor = actors[i];
            if ((uintptr_t)actor < 0x10000 || (uintptr_t)actor > 0xFFFFFFFFFFFF || !actor->RootComponent)
                continue;
            WorldMarker marker;
            marker.position = actor->K2_GetActorLocation();
            if (!WorldVectorValid(marker.position) ||
                WorldDistanceSquared(marker.position, playerPosition) > maxSquared) continue;
            marker.feature = feature;
            if (!describe((T*)actor, marker)) continue;
            markers.push_back(std::move(marker));
        }
        std::sort(markers.begin(), markers.end(), [&](const WorldMarker& a, const WorldMarker& b) {
            return WorldDistanceSquared(a.position, playerPosition) < WorldDistanceSquared(b.position, playerPosition);
        });
        if (markers.size() > limit) markers.resize(limit);
    }
}

// HMOOD__TG@i_8_f
void CaptureWorldEsp(ASTExtraPlayerCharacter* player, ASTExtraPlayerController* controller) {
    static WorldFrame cache;
    static UWorld* previousWorld = nullptr;
    static ASTExtraPlayerCharacter* previousPlayer = nullptr;
    static double itemScan = -1., boxScan = -1., vehicleScan = -1.;
    const unsigned requested = worldRequests.load(std::memory_order_acquire);
    UWorld* world = requested ? GetFullWorld() : nullptr;
    if (!world || !world->PersistentLevel || !player || !player->RootComponent ||
        !controller || !controller->PlayerCameraManager) {
        cache = WorldFrame{};
        previousWorld = nullptr;
        previousPlayer = nullptr;
        itemScan = boxScan = vehicleScan = -1.;
        std::lock_guard<std::mutex> lock(worldFrameMutex);
        worldFrame = WorldFrame{};
        return;
    }
    if (world != previousWorld || player != previousPlayer) {
        cache = WorldFrame{};
        itemScan = boxScan = vehicleScan = -1.;
        previousWorld = world;
        previousPlayer = player;
    }
    const double now = WorldTime();
    const float range = worldRange.load(std::memory_order_relaxed);
    cache.playerPosition = player->K2_GetActorLocation();
    const auto& pov = controller->PlayerCameraManager->CameraCache.POV;
    cache.cameraPosition = pov.Location;
    cache.cameraRotation = pov.Rotation;
    cache.fov = pov.FOV;
    if (!WorldVectorValid(cache.playerPosition) || !WorldVectorValid(cache.cameraPosition) ||
        !std::isfinite(cache.fov) || cache.fov <= 1.f || cache.fov >= 179.f) {
        itemScan = boxScan = vehicleScan = -1.;
        std::lock_guard<std::mutex> lock(worldFrameMutex);
        worldFrame = WorldFrame{};
        return;
    }
    cache.capturedAt = now;
    if (!(requested & WorldItems)) { cache.items.clear(); itemScan = -1.; }
    else if (itemScan < 0. || now - itemScan >= 3.) {
        CaptureWorldActors<APickUpWrapperActor>(world, cache.playerPosition, range, 240, WorldItems,
            [](APickUpWrapperActor* actor, WorldMarker& marker) {
                marker.itemID = actor->DefineID.TypeSpecificID;
                if (marker.itemID <= 0) return false;
                const char* category = WorldItemCategory(marker.itemID);
                marker.name = WorldItemName(marker.itemID);
                marker.icon = WorldItemIcon(category);
                marker.color = WorldItemColor(category);
                return true;
            }, cache.items);
        itemScan = now;
    }
    if (!(requested & WorldLootbox)) { cache.lootboxes.clear(); boxScan = -1.; }
    else if (boxScan < 0. || now - boxScan >= 3.) {
        CaptureWorldActors<APlayerTombBox>(world, cache.playerPosition, range, 64, WorldLootbox,
            [](APlayerTombBox*, WorldMarker& marker) {
                marker.name = "Lootbox";
                marker.icon = ICON_FA_BOXES;
                marker.color = IM_COL32(235, 190, 110, 255);
                return true;
            }, cache.lootboxes);
        boxScan = now;
    }
    if (!(requested & WorldVehicle)) { cache.vehicles.clear(); vehicleScan = -1.; }
    else if (vehicleScan < 0. || now - vehicleScan >= .5) {
        CaptureWorldActors<ASTExtraVehicleBase>(world, cache.playerPosition, range, 64, WorldVehicle,
            [](ASTExtraVehicleBase* actor, WorldMarker& marker) {
                CaptureVehicleDetails(actor, marker);
                return true;
            }, cache.vehicles);
        vehicleScan = now;
    }
    std::lock_guard<std::mutex> lock(worldFrameMutex);
    worldFrame = cache;
}

// HMOOD__TG@i_8_f
static void DrawVehicleRadarCard(ImDrawList* draw, ImFont* font, const WorldMarker& marker,
                                  ImVec2 screen, float distance) {
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    const float fs = 12.f * scale, height = 31.f * scale;
    char label[128];
    snprintf(label, sizeof(label), "%s [%.0fm]", marker.name.c_str(), distance);
    const ImVec2 textSize = font->CalcTextSizeA(fs, FLT_MAX, 0.f, label);
    const float width = fmaxf(70.f * scale, textSize.x + 14.f * scale);
    const float left = screen.x - width * .5f, top = screen.y - height - 8.f * scale;
    const ImVec2 a(left, top), b(left + width, top + height);
    draw->AddRect(a, b, IM_COL32(20, 158, 221, 35), 4.f * scale, 0, 4.f * scale);
    draw->AddRectFilled(a, b, IM_COL32(3, 16, 26, 240), 4.f * scale);
    draw->AddRect(a, b, IM_COL32(27, 139, 193, 240), 4.f * scale, 0,
                  1.1f * scale * ImClamp(strokeIntensity, .5f, 5.f));
    const ImVec2 position(screen.x - textSize.x * .5f, top + 4.f * scale);
    draw->AddText(font, fs, ImVec2(position.x + .6f * scale, position.y + .6f * scale),
                  IM_COL32(0, 0, 0, 180), label);
    draw->AddText(font, fs, position, IM_COL32(240, 247, 250, 255), label);
    const float barWidth = (width - 15.f * scale) * .5f, barY = top + height - 7.f * scale;
    const float ratios[] = {marker.healthRatio, marker.fuelRatio};
    const ImU32 colors[] = {IM_COL32(15, 230, 158, 255), IM_COL32(0, 205, 234, 255)};
    for (int i = 0; i < 2; ++i) {
        if (ratios[i] < 0.f) continue;
        const float x = left + 6.f * scale + i * (barWidth + 3.f * scale);
        draw->AddRectFilled(ImVec2(x, barY), ImVec2(x + barWidth, barY + 3.f * scale),
                            IM_COL32(9, 48, 58, 255), .7f * scale);
        if (ratios[i] > 0.f)
            draw->AddRectFilled(ImVec2(x, barY), ImVec2(x + barWidth * ratios[i], barY + 3.f * scale),
                                colors[i], .7f * scale);
    }
}

static void DrawWorldMarker(ImDrawList* draw, ImFont* font, const WorldMarker& marker,
                             ImVec2 screen, float distance, float maxDistance) {
    if (marker.feature == WorldVehicle) {
        DrawVehicleRadarCard(draw, font, marker, screen, distance);
        return;
    }
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    if (marker.feature == WorldItems) {
        char label[128];
        snprintf(label, sizeof(label), "%s[%.0fm]", marker.name.c_str(), distance);
        const float size = 13.f * scale;
        const ImVec2 measured = font->CalcTextSizeA(size, FLT_MAX, 0.f, label);
        const ImVec2 position(screen.x - measured.x * .5f, screen.y - measured.y);
        draw->AddText(font, size, ImVec2(position.x + .65f * scale, position.y + .65f * scale),
                      IM_COL32(0, 0, 0, 120), label);
        draw->AddText(font, size, position, marker.color, label);
        return;
    }
    const float relative = ImClamp(distance / maxDistance, 0.f, 1.f);
    const float alpha = 1.f - .4f * relative;
    ImVec4 accent = ImGui::ColorConvertU32ToFloat4(marker.color);
    accent.w *= alpha;
    const ImU32 color = ImGui::ColorConvertFloat4ToU32(accent);
    const float radius = 3.2f * scale;
    const ImVec2 diamond[] = {{screen.x, screen.y - radius}, {screen.x + radius, screen.y},
                              {screen.x, screen.y + radius}, {screen.x - radius, screen.y}};
    draw->AddConvexPolyFilled(diamond, 4, color);
    draw->AddLine(ImVec2(screen.x, screen.y - radius), ImVec2(screen.x, screen.y - 9.f * scale), color, scale);
    const float fs = 12.f * scale, height = 21.f * scale;
    const float gap = 5.f * scale;
    char meters[20];
    snprintf(meters, sizeof(meters), "%.0fm", distance);
    const ImVec2 nameSize = font->CalcTextSizeA(fs, FLT_MAX, 0.f, marker.name.c_str());
    const ImVec2 distanceSize = font->CalcTextSizeA(fs, FLT_MAX, 0.f, meters);
    const ImVec2 iconSize = font->CalcTextSizeA(fs, FLT_MAX, 0.f, marker.icon);
    const float rightWidth = fmaxf(height, distanceSize.x + gap * 2.f);
    const float width = height + gap + nameSize.x + gap + rightWidth;
    const float left = screen.x - width * .5f, top = screen.y - 9.f * scale - height;
    const ImVec2 a(left, top), b(left + width, top + height);
    draw->AddRectFilled(a, b, IM_COL32(8, 13, 19, (int)(215.f * alpha)), height * .5f);
    ImVec4 edge = bgColor.Value;
    edge.w *= alpha;
    draw->AddRect(a, b, ImGui::ColorConvertFloat4ToU32(edge), height * .5f, 0,
                  ImClamp(strokeIntensity, .5f, 5.f) * scale);
    draw->AddLine(ImVec2(left + height, top + 3.f * scale),
                  ImVec2(left + height, top + height - 3.f * scale), color, scale);
    draw->AddText(font, fs, ImVec2(left + (height - iconSize.x) * .5f,
                  top + (height - iconSize.y) * .5f), color, marker.icon);
    const ImVec2 namePosition(left + height + gap, top + (height - nameSize.y) * .5f);
    const ImU32 text = IM_COL32(238, 242, 247, (int)(255.f * alpha));
    if (textBorder) DrawEspTextStroke(draw, font, fs, namePosition, text, marker.name.c_str());
    else draw->AddText(font, fs, namePosition, text, marker.name.c_str());
    const ImVec2 distancePosition(left + width - rightWidth * .5f - distanceSize.x * .5f,
                                  top + (height - distanceSize.y) * .5f);
    if (textBorder) DrawEspTextStroke(draw, font, fs, distancePosition, color, meters);
    else draw->AddText(font, fs, distancePosition, color, meters);
}

// HMOOD__TG@i_8_f
void DrawWorldEsp() {
    const unsigned requested = (imgui::Items ? WorldItems : 0u) |
                               (imgui::Lootbox ? WorldLootbox : 0u) |
                               (imgui::Vehicle ? WorldVehicle : 0u);
    const float range = ImClamp(ESPMaxDistance, 1.f, 450.f);
    worldRange.store(range, std::memory_order_relaxed);
    worldRequests.store(requested, std::memory_order_release);
    if (!requested) return;
    WorldFrame frame;
    {
        std::lock_guard<std::mutex> lock(worldFrameMutex);
        frame = worldFrame;
    }
    if (frame.capturedAt <= 0. || WorldTime() - frame.capturedAt > .75 ||
        !WorldVectorValid(frame.cameraPosition) || !WorldVectorValid(frame.playerPosition) ||
        !std::isfinite(frame.fov) || frame.fov <= 1.f || frame.fov >= 179.f) return;
    const float radians = 3.14159265f / 180.f;
    const float sp = sinf(frame.cameraRotation.Pitch * radians), cp = cosf(frame.cameraRotation.Pitch * radians);
    const float sy = sinf(frame.cameraRotation.Yaw * radians), cy = cosf(frame.cameraRotation.Yaw * radians);
    const float sr = sinf(frame.cameraRotation.Roll * radians), cr = cosf(frame.cameraRotation.Roll * radians);
    const FVector forward{cp * cy, cp * sy, sp};
    const FVector right{sr * sp * cy - cr * sy, sr * sp * sy + cr * cy, -sr * cp};
    const FVector up{-(cr * sp * cy + sr * sy), cy * sr - cr * sp * sy, cr * cp};
    const ImVec2 size = ImGui::GetIO().DisplaySize;
    const float focal = size.x * .5f / tanf(frame.fov * radians * .5f);
    ImFont* font = cyberMenuFont ? cyberMenuFont : mainFont;
    if (!font || !std::isfinite(focal)) return;
    ImDrawList* draw = ImGui::GetBackgroundDrawList();
    auto render = [&](const std::vector<WorldMarker>& markers) {
        for (const auto& marker : markers) {
            if (!(requested & marker.feature)) continue;
            const float distance = sqrtf(WorldDistanceSquared(marker.position, frame.playerPosition)) / 100.f;
            if (!std::isfinite(distance) || distance > range) continue;
            const FVector delta{marker.position.X - frame.cameraPosition.X,
                                marker.position.Y - frame.cameraPosition.Y,
                                marker.position.Z - frame.cameraPosition.Z};
            const float depth = delta.X * forward.X + delta.Y * forward.Y + delta.Z * forward.Z;
            if (depth <= 1.f) continue;
            const float horizontal = delta.X * right.X + delta.Y * right.Y + delta.Z * right.Z;
            const float vertical = delta.X * up.X + delta.Y * up.Y + delta.Z * up.Z;
            const ImVec2 screen(size.x * .5f + horizontal * focal / depth,
                                size.y * .5f - vertical * focal / depth);
            if (!std::isfinite(screen.x) || !std::isfinite(screen.y) ||
                screen.x < -40.f || screen.x > size.x + 40.f ||
                screen.y < -40.f || screen.y > size.y + 40.f) continue;
            DrawWorldMarker(draw, font, marker, screen, distance, range);
        }
    };
    render(frame.items);
    render(frame.lootboxes);
    render(frame.vehicles);
}


ImVec2 DrawCyberHealthCard(ASTExtraPlayerCharacter* p, ImDrawList* draw, ImVec2 head)
{
    if (!p || !draw || !mainFont) return ImVec2(0,0);
    const float scale=HealthCardScale();
    const float w=124.f*scale,h=34.f*scale;
    const float x=head.x-w*.5f,y=head.y-h-10.f*scale;
    const bool alive=p->Health>0.f;
    const float maximum=fmaxf(p->HealthMax,1.f);
    const float amount=ImClamp((alive?p->Health:p->NearDeathBreath)/maximum,0.f,1.f);
    const ImU32 cyan=alive?IM_COL32(22,200,242,255):IM_COL32(244,36,67,255);
    draw->AddRectFilled(ImVec2(x-1*scale,y+1*scale),ImVec2(x+w+1*scale,y+h+1*scale),IM_COL32(0,0,0,100),3*scale);
    draw->AddRectFilled(ImVec2(x,y),ImVec2(x+w,y+h),IM_COL32(4,15,26,238),3*scale);
    draw->AddRect(ImVec2(x,y),ImVec2(x+w,y+h),ImGui::ColorConvertFloat4ToU32(bgColor.Value),3*scale,0,1.1f*scale*ImClamp(strokeIntensity,.5f,5.f));
    draw->AddRect(ImVec2(x+1.5f*scale,y+1.5f*scale),ImVec2(x+w-1.5f*scale,y+h-1.5f*scale),IM_COL32(7,39,62,180),2*scale,0,.65f*scale);
    const float chipW=25.f*scale;
    draw->AddRectFilledMultiColor(ImVec2(x+3*scale,y+4*scale),ImVec2(x+chipW,y+h-9*scale),
        IM_COL32(10,55,85,230),IM_COL32(7,28,44,100),IM_COL32(7,28,44,100),IM_COL32(10,55,85,230));
    ImFont* font=cyberMenuFont?cyberMenuFont:mainFont;
    char hp[12];snprintf(hp,sizeof(hp),"%.0f",amount*100.f);
    const float hpFont=10.f*scale;
    const ImVec2 hpSize=font->CalcTextSizeA(hpFont,FLT_MAX,0.f,hp);
    draw->AddText(font,hpFont,ImVec2(x+(chipW-hpSize.x)*.5f,y+9.f*scale),cyan,hp);
    if(imgui::Name) {
        const bool bot=p->bIsAI || p->bEnsure;
        std::string label=bot?"BOT":"PLAYER";
        if(!bot) {
            const auto& name=p->PlayerName;
            const int count=name.GetLength();
             
            if(name.GetData() && count>0 && count<256) {
                CFStringRef value=CFStringCreateWithCharacters(kCFAllocatorDefault,(const UniChar*)name.GetData(),count);
                if(value) {
                    char utf8[1024];
                    if(CFStringGetCString(value,utf8,sizeof(utf8),kCFStringEncodingUTF8) && utf8[0])label=utf8;
                    CFRelease(value);
                }
            }
        }
        float fs=11.f*scale;
        ImVec2 ts=font->CalcTextSizeA(fs,FLT_MAX,0.f,label.c_str());
        const float room=w-chipW-8*scale;
        if(ts.x>room){fs*=room/ts.x;ts=font->CalcTextSizeA(fs,FLT_MAX,0.f,label.c_str());}
        const ImVec2 pos(x+chipW+(w-chipW-ts.x)*.5f,y+8.5f*scale);
        draw->PushClipRect(ImVec2(x+chipW,y+3*scale),ImVec2(x+w-3*scale,y+h-8*scale),true);
        draw->AddText(font,fs,pos,IM_COL32(232,240,247,255),label.c_str());
        draw->PopClipRect();
    }
    const float railX=x+3*scale,railY=y+h-7*scale,railW=w-6*scale;
    draw->AddRectFilled(ImVec2(railX,railY),ImVec2(railX+railW,railY+4*scale),IM_COL32(8,45,66,255),1*scale);
    if(amount>0.f) {
        draw->AddRectFilled(ImVec2(railX,railY),ImVec2(railX+railW*amount,railY+4*scale),cyan,1*scale);
        draw->AddLine(ImVec2(railX,railY+.7f*scale),ImVec2(railX+railW*amount,railY+.7f*scale),alive?IM_COL32(107,232,255,200):IM_COL32(255,132,146,180),.75f*scale);
    }
    return ImVec2(x+w*.5f,y+h*.5f);
}

ImVec2 DrawHealthVnHax(ASTExtraPlayerCharacter* p, ImDrawList* draw)
{
    if(!p || !p->RootComponent)return ImVec2(0,0);
    FVector head=p->GetBonePos("Head",FVector());
    FVector2D screen;
    if(!WorldToScreenBone(head,&screen))return ImVec2(0,0);
    return DrawCyberHealthCard(p,draw,ImVec2(screen.X * espProjectionScale.x, screen.Y * espProjectionScale.y));
}

void DrawPlayerName(ASTExtraPlayerCharacter* p, ImDrawList* d, bool textBorder)
{
    if (!p || !p->RootComponent)
        return;

    FVector root = p->RootComponent->K2_GetComponentLocation();

    FVector feetPos = root;
    feetPos.Z -= 100.0f;

    FVector2D screenPos;
    if (!WorldToScreenBone(feetPos, &screenPos))
        return;

    screenPos.X *= espProjectionScale.x;
    screenPos.Y *= espProjectionScale.y;

    std::wstring wnm = p->PlayerName.ToWString();
    std::string playerName(wnm.begin(), wnm.end());
    if (playerName.empty())
        playerName = "BOT";

    float nameFontSize = 8.0f;

    ImVec2 nameSize = mainFont->CalcTextSizeA(
        nameFontSize,
        FLT_MAX,
        0.0f,
        playerName.c_str()
    );

    ImVec2 namePos;

    namePos.x = screenPos.X - nameSize.x * 0.5f;

    namePos.y = screenPos.Y + 10.0f - nameSize.y - 2.0f;

    if (textBorder)
        DrawEspTextStroke(d, 
            mainFont,
            nameFontSize,
            namePos,
            IM_COL32(0, 0, 0, 200),
            playerName.c_str()
        );

    d->AddText(
        mainFont,
        nameFontSize,
        namePos,
        IM_COL32(255, 255, 255, 255),
        playerName.c_str()
    );
}

void DrawTeamID(ASTExtraPlayerCharacter* p, ImDrawList* d, ImVec2 healthPos, bool textBorder)
{
    if (!p || !p->RootComponent) return;

    FVector root = p->RootComponent->K2_GetComponentLocation();
    FVector headPos = root;
    headPos.Z += 90.0f;

    FVector2D screenHead;
    if (!WorldToScreenBone(headPos, &screenHead))
        return;

    screenHead.X *= espProjectionScale.x;
    screenHead.Y *= espProjectionScale.y;

    std::string teamStr = "Team " + std::to_string(p->TeamID);
    float teamFontSize = 10.0f;
    float weaponFontSize = 9.5f;

    ImVec2 teamSize  = mainFont->CalcTextSizeA(teamFontSize,   FLT_MAX, 0.0f, teamStr.c_str());
    float  weaponH   = mainFont->CalcTextSizeA(weaponFontSize, FLT_MAX, 0.0f, "W").y;

    ImVec2 textPos;
    textPos.x = screenHead.X - teamSize.x * 0.5f;
    textPos.y = screenHead.Y - weaponH - 5.0f - teamSize.y - 2.0f;
    if(imgui::Health)textPos.y-=24.f*HealthCardScale();

    if (textBorder)
        DrawEspTextStroke(d, mainFont, teamFontSize, textPos, IM_COL32(0,0,0,200), teamStr.c_str());

    d->AddText(mainFont, teamFontSize, textPos, IM_COL32(255,255,0,255), teamStr.c_str());
}

void DrawWeaponName(ASTExtraPlayerCharacter* p, ImDrawList* d, bool textBorder)
{
    if (!p || !p->RootComponent)
        return;

    FVector root = p->RootComponent->K2_GetComponentLocation();

    FVector headPos = root;
    headPos.Z += 90.0f;

    FVector2D screenHead;
    if (!WorldToScreenBone(headPos, &screenHead))
        return;

    screenHead.X *= espProjectionScale.x;
    screenHead.Y *= espProjectionScale.y;

    std::string weaponName = "Fist";
    if (auto wm = p->WeaponManagerComponent)
    {
        auto slot = wm->GetCurrentUsingPropSlot();
        if ((int)slot.GetValue() >= 1 && (int)slot.GetValue() <= 3)
        {
            if (auto cw = wm->CurrentWeaponReplicated)
                weaponName = cw->GetWeaponName().ToString();
        }
    }

    float weaponFontSize = 9.5f;

    ImVec2 weaponSize = mainFont->CalcTextSizeA(
        weaponFontSize,
        FLT_MAX,
        0.0f,
        weaponName.c_str()
    );

    ImVec2 textPos;

    textPos.x = screenHead.X - weaponSize.x * 0.5f;
    textPos.y = screenHead.Y - weaponSize.y - 5.0f;
    if(imgui::Health)textPos.y-=38.f*HealthCardScale();

    if (textBorder)
        DrawEspTextStroke(d, 
            mainFont,
            weaponFontSize,
            textPos,
            IM_COL32(0,0,0,200),
            weaponName.c_str()
        );

    d->AddText(
        mainFont,
        weaponFontSize,
        textPos,
        IM_COL32(255,255,255,255),
        weaponName.c_str()
    );
}

static void DrawPlayerDistance(ImDrawList* draw, ImVec2 feet, float distance) {
    if (!draw || !std::isfinite(distance) || distance <= .5f) return;
    ImFont* font = cyberMenuFont ? cyberMenuFont : mainFont;
    if (!font) return;
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    const float fs = 12.f * scale;
    char meters[24];
    snprintf(meters, sizeof(meters), "%.0fm", distance);
    const ImVec2 size = font->CalcTextSizeA(fs, FLT_MAX, 0.f, meters);
    const ImVec2 position(feet.x - size.x * .5f, feet.y + 7.f * scale);
    if (textBorder) DrawEspTextStroke(draw, font, fs, position, COLOR_Distance, meters);
    else {
        draw->AddText(font, fs, ImVec2(position.x + .6f * scale, position.y + .6f * scale),
                      IM_COL32(0, 0, 0, 160), meters);
        draw->AddText(font, fs, position, COLOR_Distance, meters);
    }
}

static void DrawPlayerCornerBox(ImDrawList* draw, ImVec2 head, ImVec2 feet) {
    const float height = feet.y - head.y;
    if (!draw || !std::isfinite(height) || height < 3.f) return;
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    const float halfWidth = height * .225f, center = (head.x + feet.x) * .5f;
    const float left = center - halfWidth, right = center + halfWidth;
    const float horizontal = fminf(halfWidth * .8f, fmaxf(halfWidth * .52f, 1.5f * scale));
    const float vertical = fminf(horizontal, height * .2f);
    const float thickness = ImClamp(strokeIntensity, .5f, 5.f) * scale;
    for (int pass = 0; pass < 2; ++pass) {
        const ImU32 color = pass ? IM_COL32(255, 255, 255, 255) : IM_COL32(0, 0, 0, 105);
        const float width = thickness + (pass ? 0.f : 1.2f * scale);
        for (int side = 0; side < 2; ++side) {
            const float x = side ? right : left, direction = side ? -1.f : 1.f;
            draw->AddLine(ImVec2(x, head.y), ImVec2(x + horizontal * direction, head.y), color, width);
            draw->AddLine(ImVec2(x, head.y), ImVec2(x, head.y + vertical), color, width);
            draw->AddLine(ImVec2(x, feet.y), ImVec2(x + horizontal * direction, feet.y), color, width);
            draw->AddLine(ImVec2(x, feet.y), ImVec2(x, feet.y - vertical), color, width);
        }
    }
}

// HMOOD__TG@i_8_f
void DrawSkeletonAdvanced(ASTExtraPlayerCharacter* player, bool isBot, bool isVisible) {
    if (!player || !player->RootComponent || !player->Mesh || !g_PlayerController) return;
    static const char* bones[] = {
        "Head", "neck_01", "spine_03", "spine_01", "pelvis",
        "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l",
        "thigh_r", "calf_r", "foot_r", "thigh_l", "calf_l", "foot_l"
    };
    static const int links[][2] = {
        {1,2}, {2,3}, {3,4}, {2,5}, {5,6}, {6,7}, {2,8}, {8,9}, {9,10},
        {4,11}, {11,12}, {12,13}, {4,14}, {14,15}, {15,16}
    };
    ImVec2 points[17];
    bool valid[17] = {};
    for (int i = 0; i < 17; ++i) {
        const FVector bone = player->GetBonePos(bones[i], {});
        if (!(bone.X || bone.Y || bone.Z)) continue;
        FVector2D screen;
        if (!WorldToScreenBone(bone, &screen)) continue;
        points[i] = ImVec2(screen.X * espProjectionScale.x, screen.Y * espProjectionScale.y);
        valid[i] = std::isfinite(points[i].x) && std::isfinite(points[i].y);
    }
    const Color255& tone = isBot ? (isVisible ? botVisibleColor : botInvisibleColor)
                                : (isVisible ? realVisibleColor : realInvisibleColor);
    const ImU32 color = IM_COL32(tone.r, tone.g, tone.b, tone.a);
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    const float thickness = fmaxf(.8f, 1.05f * scale);
    ImDrawList* draw = ImGui::GetBackgroundDrawList();
    const ImVec2 display = ImGui::GetIO().DisplaySize;
    auto segment = [&](ImVec2 a, ImVec2 b) {
        const float dx = a.x - b.x, dy = a.y - b.y;
        if (dx * dx + dy * dy > display.y * display.y * .36f) return;
        draw->AddLine(a, b, color, thickness);
    };
    for (const auto& link : links)
        if (valid[link[0]] && valid[link[1]]) segment(points[link[0]], points[link[1]]);
    if (valid[0] && valid[1]) {
        const float dx = points[0].x - points[1].x, dy = points[0].y - points[1].y;
        const float length = sqrtf(dx * dx + dy * dy);
        const float radius = ImClamp(length * .48f, 1.8f * scale, 4.8f * scale);
        if (length > .01f)
            segment(points[1], ImVec2(points[0].x - dx * radius / length, points[0].y - dy * radius / length));
        draw->AddCircle(points[0], radius, color, 20, thickness);
    }
    const int joints[] = {1, 2, 4, 6, 9, 12, 15};
    for (int joint : joints)
        if (valid[joint]) draw->AddCircleFilled(points[joint], .9f * scale, color, 10);
}

static ImVec2 HudLineOrigin() {
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    return ImVec2(ImGui::GetIO().DisplaySize.x * .5f, 94.f * scale);
}

// HMOOD__TG@i_8_f
static void DrawEnemyAimingWarning(bool active) {
    static bool showing = false;
    static double started = 0.;
    const double now = std::chrono::duration<double>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
    if (!active) {
        showing = false;
        return;
    }
    if (!showing) started = now;
    showing = true;
    const bool yellow = std::fmod(now - started, .8) >= .4;
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    const float size = 50.f * scale, cx = ImGui::GetIO().DisplaySize.x * .5f;
    const float top = 128.f * scale;
    ImDrawList* draw = ImGui::GetForegroundDrawList();
    const ImVec2 a(cx - size * .5f, top), b(cx + size * .5f, top + size);
    draw->AddRect(a, b, IM_COL32(255, 13, 55, 26), 11.f * scale, 0, 9.f * scale);
    draw->AddRect(a, b, IM_COL32(255, 18, 57, 64), 11.f * scale, 0, 6.f * scale);
    draw->AddRectFilled(a, b, IM_COL32(13, 3, 9, 250), 11.f * scale);
    draw->AddRect(a, b, IM_COL32(242, 20, 53, 255), 11.f * scale, 0, 3.8f * scale);
    draw->AddRect(ImVec2(a.x + 2.f * scale, a.y + 2.f * scale),
                  ImVec2(b.x - 2.f * scale, b.y - 2.f * scale),
                  IM_COL32(255, 62, 88, 65), 9.f * scale, 0, .8f * scale);
    const float middle = top + size * .53f;
    const ImVec2 triangle[] = {
        ImVec2(cx, middle - 14.f * scale),
        ImVec2(cx + 13.f * scale, middle + 10.f * scale),
        ImVec2(cx - 13.f * scale, middle + 10.f * scale)
    };
    for (int i = 0; i < 3; ++i) {
        const ImVec2 previous = triangle[(i + 2) % 3], corner = triangle[i], next = triangle[(i + 1) % 3];
        const ImVec2 enter(corner.x + (previous.x - corner.x) * .12f,
                           corner.y + (previous.y - corner.y) * .12f);
        const ImVec2 leave(corner.x + (next.x - corner.x) * .12f,
                           corner.y + (next.y - corner.y) * .12f);
        draw->PathLineTo(enter);
        draw->PathBezierQuadraticCurveTo(corner, leave, 4);
    }
    draw->PathFillConvex(yellow ? IM_COL32(255, 225, 45, 255) : IM_COL32(255, 21, 66, 255));
    draw->AddRectFilled(ImVec2(cx - 1.7f * scale, middle - 6.f * scale),
                        ImVec2(cx + 1.7f * scale, middle + 1.f * scale),
                        IM_COL32(18, 3, 9, 255), 1.7f * scale);
    draw->AddCircleFilled(ImVec2(cx, middle + 6.f * scale), 1.7f * scale, IM_COL32(18, 3, 9, 255), 16);
}

void Draw360Alert(const std::vector<ASTExtraPlayerCharacter*>& enemies)
{
    if(!g_LocalPlayer || !g_LocalPlayer->RootComponent || !mainFont)return;
    ImDrawList* draw=ImGui::GetForegroundDrawList();
    const ImGuiIO& io=ImGui::GetIO();
    const float scale=ImClamp(io.DisplaySize.y/592.f,.55f,1.4f);
    const ImVec2 center(io.DisplaySize.x*.5f,io.DisplaySize.y*.5f);
    const FVector playerPos=g_LocalPlayer->RootComponent->K2_GetComponentLocation();
    FVector forward=g_LocalPlayer->GetActorForwardVector();
    forward.Z=0;forward=NormalizeVector(forward);
    const float radius=ImClamp(AlertRadius,24.f,fmaxf(24.f,fminf(io.DisplaySize.x,io.DisplaySize.y)*.42f));
    const float length=23.f*scale,half=9.f*scale;
    ImFont* font=cyberMenuFont?cyberMenuFont:mainFont;
    for(auto* p:enemies) {
        if(!p || p->bDead || !p->RootComponent)continue;
        if(imgui::HideBot && (p->bIsAI || p->bEnsure))continue;
        const FVector delta=p->RootComponent->K2_GetComponentLocation()-playerPos;
        const float distance=sqrtf(delta.X*delta.X+delta.Y*delta.Y+delta.Z*delta.Z)/100.f;
        if(distance<.5f || (ESPMaxDistance>0.f && distance>ESPMaxDistance))continue;
        FVector bearing=delta;bearing.Z=0;bearing=NormalizeVector(bearing);
        const float angle=atan2f(forward.X*bearing.Y-forward.Y*bearing.X,forward.X*bearing.X+forward.Y*bearing.Y);
        const float dx=sinf(angle),dy=-cosf(angle),px=-dy,py=dx;
        const float cx=center.x+dx*radius,cy=center.y+dy*radius;
        const ImVec2 tip(cx+dx*length*.56f,cy+dy*length*.56f);
        const ImVec2 left(cx-dx*length*.44f-px*half,cy-dy*length*.44f-py*half);
        const ImVec2 right(cx-dx*length*.44f+px*half,cy-dy*length*.44f+py*half);
        const ImVec2 notch(cx-dx*length*.16f,cy-dy*length*.16f);
        const ImU32 red=IM_COL32(255,11,48,255);
         
        draw->AddTriangleFilled(tip,left,notch,red);
        draw->AddTriangleFilled(tip,notch,right,red);
        const ImVec2 rim[]={tip,left,notch,right};
        draw->AddPolyline(rim,4,IM_COL32(55,0,10,230),ImDrawFlags_Closed,1.25f*scale);
        draw->AddLine(tip,left,IM_COL32(255,93,106,150),.7f*scale);
        char meters[20];snprintf(meters,sizeof(meters),"%.0fm",distance);
        const float fs=10.f*scale;
        const ImVec2 ts=font->CalcTextSizeA(fs,FLT_MAX,0.f,meters);
        const ImVec2 label(cx+dx*(length*.62f+9*scale)-ts.x*.5f,cy+dy*(length*.62f+9*scale)-ts.y*.5f);
        draw->AddText(font,fs,ImVec2(label.x+.7f*scale,label.y+.7f*scale),IM_COL32(0,0,0,230),meters);
        draw->AddText(font,fs,label,IM_COL32(248,245,245,255),meters);
    }
}

static void DrawEnemyCounters(int players, int bots) {
    ImFont* font = cyberMenuFont ? cyberMenuFont : mainFont;
    if (!font) return;
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    const float fs = 15.f * scale, height = 30.f * scale, gap = 11.f * scale, top = 64.f * scale;
    char labels[2][32];
    snprintf(labels[0], sizeof(labels[0]), "ENEMY: %d", players);
    snprintf(labels[1], sizeof(labels[1]), "BOTS: %d", bots);
    const ImVec2 sizes[] = {font->CalcTextSizeA(fs, FLT_MAX, 0.f, labels[0]),
                            font->CalcTextSizeA(fs, FLT_MAX, 0.f, labels[1])};
    const float widths[] = {fmaxf(120.f * scale, sizes[0].x + 33.f * scale),
                            fmaxf(106.f * scale, sizes[1].x + 33.f * scale)};
    const ImU32 accents[] = {IM_COL32(25, 210, 237, 255), IM_COL32(250, 183, 20, 255)};
    const ImU32 backgrounds[] = {IM_COL32(9, 29, 42, 229), IM_COL32(32, 27, 9, 234)};
    float left = (ImGui::GetIO().DisplaySize.x - widths[0] - widths[1] - gap) * .5f;
    ImDrawList* draw = ImGui::GetForegroundDrawList();
    for (int i = 0; i < 2; ++i) {
        const ImVec2 a(left, top), b(left + widths[i], top + height);
        draw->AddRectFilled(a, b, backgrounds[i], 9.f * scale);
        draw->AddRect(a, b, accents[i], 9.f * scale, 0, 1.3f * scale);
        const ImVec2 dot(left + 13.f * scale, top + height * .5f);
        ImVec4 glow = ImGui::ColorConvertU32ToFloat4(accents[i]);
        glow.w = .13f;
        draw->AddCircleFilled(dot, 6.f * scale, ImGui::ColorConvertFloat4ToU32(glow), 24);
        draw->AddCircleFilled(dot, 3.6f * scale, accents[i], 24);
        draw->AddText(font, fs, ImVec2(left + 25.f * scale, top + (height - sizes[i].y) * .5f),
                      IM_COL32(225, 229, 229, 255), labels[i]);
        left += widths[i] + gap;
    }
}

void DrawGameInfo()
{
    if (!imgui::GameInfo)
        return;

    ImGui::SetNextWindowPos(ImVec2(20, 325), ImGuiCond_Always);
    ImGuiWindowFlags flags = ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                             ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoCollapse |
                             ImGuiWindowFlags_NoScrollWithMouse | ImGuiWindowFlags_AlwaysAutoResize | 
                             ImGuiWindowFlags_NoBackground;

    if (ImGui::Begin("Game Information", nullptr, flags)) {
        ImGui::SetWindowFontScale(0.8f);   
        static ASTExtraGameStateBase* cachedGameState = nullptr;
        static float lastUpdate = 0.f;
        float now = ImGui::GetTime();
        if (!cachedGameState || now - lastUpdate > 5.f) {
            cachedGameState = nullptr;
            std::vector<ASTExtraGameStateBase*> actors;
            GetAllActors<ASTExtraGameStateBase>(actors);
            if (!actors.empty()) cachedGameState = actors[0];
            lastUpdate = now;
        }
        ASTExtraGameStateBase* InGame = cachedGameState;
        if (InGame) {
            static bool blink = true;
            static float blinkTimer = 0.0f;
            blinkTimer += ImGui::GetIO().DeltaTime;
            if (blinkTimer > 0.5f) { blink = !blink; blinkTimer = 0.0f; }
            ImVec4 ballColor = blink ? ImVec4(1, 0, 0, 1) : ImVec4(0, 0, 0, 0);
            ImGui::TextColored(ballColor, ICON_FA_CIRCLE);
            ImGui::SameLine();
            ImGui::Text("Game Information");
            if (InGame->AliveTeamNum == 1) ImGui::Text("WINNER WINNER CHICKEN DINNER");
            ImGui::Text("%d Players alive, %d Teams, %d Eliminated", (int)InGame->AlivePlayerNum, (int)InGame->AliveTeamNum, (int)(InGame->PlayerNum - InGame->AlivePlayerNum));
            const char* TEAMTYPE = (InGame->PlayerNumPerTeam == 1) ? "Solo" : (InGame->PlayerNumPerTeam == 2) ? "Duo" : (InGame->PlayerNumPerTeam == 4) ? "Squad" : "Detecting Mode";
            ImGui::Text("Team Type: %s", TEAMTYPE);
            ImGui::Text("Match ID: %d, Match Time: %ds | %dm", (int)InGame->GameID, (int)InGame->ElapsedTime, (int)InGame->ElapsedTime / 60);
            ImGui::Text("In Match (%ds)", (int)InGame->ElapsedTime);
        }
    }

    ImGui::End();
}

void DrawFOVCircle(float Cross)
{
    if (!Settings::Aimbot::SilentAimSettings::EnableFov)
        return;
    if (Cross <= 0.0f) return;  

    ImDrawList* d = ImGui::GetBackgroundDrawList();
    ImVec2 displaySize = ImGui::GetIO().DisplaySize;
    ImVec2 center = ImVec2(displaySize.x / 2.0f, displaySize.y / 2.0f);

    float radius = Cross;

    d->AddCircle(
        center,
        radius,
        IM_COL32(255, 255, 255, 255),
        100,
        1.0f
    );
}

bool WorldToScreenBone(const FVector& WorldLocation, FVector2D* Out)
{
    if (!g_PlayerController || !Out)
        return false;
    
    return UGameplayStatics::ProjectWorldToScreen(g_PlayerController, WorldLocation, false, Out);
}

void DrawAimingLine()
{
    if (!Settings::Aimbot::SilentAimSettings::AimingLine || !g_PlayerController)
        return;

    ImDrawList* d = ImGui::GetBackgroundDrawList();

    ASTExtraPlayerCharacter* Target = GetTargetByCrossDist();
    if (!Target) return;

    FVector headPos = Target->GetBonePos("Head", {});
    FVector2D hs;

    if (!g_PlayerController->ProjectWorldLocationToScreen(headPos, false, &hs))
        return;

    ImVec2 screenCenter = ImVec2(ImGui::GetIO().DisplaySize.x * 0.5f,
                                 ImGui::GetIO().DisplaySize.y * 0.5f);

    const float screenWidth = ImGui::GetIO().DisplaySize.x;
    const float screenHeight = ImGui::GetIO().DisplaySize.y;
    int viewportWidth = 0, viewportHeight = 0;
    g_PlayerController->GetViewportSize(&viewportWidth, &viewportHeight);
    if (viewportWidth <= 0 || viewportHeight <= 0) return;
    hs.X *= screenWidth / viewportWidth;
    hs.Y *= screenHeight / viewportHeight;
    if (hs.X >= 0.f && hs.X <= screenWidth && hs.Y >= 0.f && hs.Y <= screenHeight)
        d->AddLine(screenCenter, ImVec2(hs.X, hs.Y), IM_COL32(255, 255, 255, 255), 1.f);
}



// HMOOD__TG@i_8_f
void Drawesp() {
    ImGuiWindowFlags f = ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize |
                         ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoCollapse |
                         ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoInputs |
                         ImGuiWindowFlags_NoBackground;

    ImGui::SetNextWindowPos(ImVec2(0, 0));
    ImGui::SetNextWindowSize(ImGui::GetIO().DisplaySize);
    ImGui::PushStyleVar(ImGuiStyleVar_Alpha, 1.f);

    if (!ImGui::Begin("ESPOverlay", nullptr, f)) { ImGui::End(); ImGui::PopStyleVar(); return; }

    ImDrawList* d = ImGui::GetWindowDrawList();
    ImDrawList* bg = d;

    auto lp = g_LocalPlayer;

    if (!lp || !lp->RootComponent || !mainFont) {
        ImGui::End(); ImGui::PopStyleVar(); return;
    }

    int viewportWidth = 0, viewportHeight = 0;
    if (!g_PlayerController) { ImGui::End(); ImGui::PopStyleVar(); return; }
    g_PlayerController->GetViewportSize(&viewportWidth, &viewportHeight);
    if (viewportWidth <= 0 || viewportHeight <= 0) { ImGui::End(); ImGui::PopStyleVar(); return; }
    espProjectionScale = ImVec2(ImGui::GetIO().DisplaySize.x / viewportWidth,
                                ImGui::GetIO().DisplaySize.y / viewportHeight);
    int localTeamID = lp->TeamID;
    static std::vector<ASTExtraPlayerCharacter*> cache;
    static float lastUpdate = 0.f;
    float now = ImGui::GetTime();
    std::vector<ASTExtraPlayerCharacter*> tmp;

    if (now - lastUpdate > 0.7f) { GetAllActors(tmp); cache.clear(); for (auto* a : tmp) { if (!a || !a->RootComponent) continue; if (a == lp) continue; if (a->bDead) continue; if (a->TeamID == localTeamID) continue; cache.push_back(a); }

        lastUpdate = now;
    }
    bool isVisible = false;
    UGameplayStatics *gGameplayStatics = (UGameplayStatics *) UGameplayStatics::StaticClass();

    FVector lpPos = lp->RootComponent->K2_GetComponentLocation();
    ImVec2 screenCenter(ImGui::GetIO().DisplaySize.x * 0.5f, ImGui::GetIO().DisplaySize.y * 0.5f);
    int totalEnemies1 = 0;
    int totalBots1 = 0;
    bool enemyAimingAtUs = false;

    for (auto* p : cache) {
    if (!p || !p->RootComponent) continue;
    if (p->bDead) continue;
    if (!imgui::ESP) continue;

    bool isBot = (p->bIsAI || p->bEnsure);

    if (imgui::HideBot && isBot)
        continue;

    if (isBot)
        ++totalBots1;
    else
        ++totalEnemies1;

        FVector root = p->RootComponent->K2_GetComponentLocation();
        FVector diff = lpPos - root;
        float distVal = sqrtf(diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z) / 100.f;
        if (ESPMaxDistance > 0.f && distVal > ESPMaxDistance) continue;
        if (imgui::EnemyAiming && !enemyAimingAtUs && bIsAimingAtLocalPlayer(p))
            enemyAimingAtUs = true;
        FVector head = p->GetBonePos("Head", FVector());
        FVector feet = root;
        feet.Z -= 100.f;
        const FVector leftFoot = p->GetBonePos("foot_l", {}), rightFoot = p->GetBonePos("foot_r", {});
        if ((leftFoot.X || leftFoot.Y || leftFoot.Z) && (rightFoot.X || rightFoot.Y || rightFoot.Z)) {
            feet = FVector{(leftFoot.X + rightFoot.X) * .5f, (leftFoot.Y + rightFoot.Y) * .5f,
                           fminf(leftFoot.Z, rightFoot.Z) - 3.f};
        }
        FVector2D hs{}, fs{}, footScreen{};
        const bool headOk = W2S(head, &hs), rootOk = W2S(root, &fs);
        const bool feetOk = W2S(feet, &footScreen);
        if (!headOk && !rootOk) continue;
        if (!headOk) hs = fs;
        if (!rootOk) fs = hs;
        hs.X *= espProjectionScale.x; hs.Y *= espProjectionScale.y;
        fs.X *= espProjectionScale.x; fs.Y *= espProjectionScale.y;
        footScreen.X *= espProjectionScale.x; footScreen.Y *= espProjectionScale.y;
        if (imgui::Boxes && headOk && feetOk) {
            FVector top = head;
            top.Z += 10.f;
            FVector2D corner;
            if (W2S(top, &corner))
                DrawPlayerCornerBox(d, ImVec2(corner.X * espProjectionScale.x, corner.Y * espProjectionScale.y),
                                      ImVec2(footScreen.X, footScreen.Y));
        }
        if (imgui::Distance && feetOk)
            DrawPlayerDistance(d, ImVec2(footScreen.X, footScreen.Y), distVal);

        float asize = 80.0f / (distVal > 0 ? distVal : 1.0f);
        if (asize > 1.0f) asize = 1.0f;
        if (asize < 0.3f) asize = 0.3f;

 
isVisible = false;
const char* checkBones[] = {"Head", "neck_01", "pelvis", "spine_03"};
for (const char* bone : checkBones) {
    FVector bonePos = p->GetBonePos(bone, {});
    if (bonePos.X == 0 && bonePos.Y == 0 && bonePos.Z == 0) continue;
    if (g_PlayerController->LineOfSightTo(p, bonePos, true)) { isVisible = true; break; }
}

if (IsStyle == 0)
{
     
    ImVec2 LocationScreen(fs.X, fs.Y);
    {
        float Playersize_y = LocationScreen.y - hs.Y;
        if (Playersize_y < 1.5f) goto skipBasicESP;
        float bT = LocationScreen.y - Playersize_y;
        ImColor boxColor = isBot ? ImColor(50,255,80,255) : ImColor(255,50,50,255);
        ImU32 boxU32 = (ImU32)boxColor;

         
        if (imgui::Health)DrawCyberHealthCard(p,d,ImVec2(hs.X,bT));
        if (imgui::TeamID && imgui::Health)DrawTeamID(p,d,ImVec2(hs.X,bT),textBorder);

        if (imgui::Name && !imgui::Health) {
            std::string nameStr;
            if (isBot) {
                nameStr = "\xef\x95\x84";
            } else {
                std::wstring wnm = p->PlayerName.ToWString();
                nameStr = std::string(wnm.begin(), wnm.end());
                if (nameStr.empty()) nameStr = "?";
            }
            const float nfs = 9.5f;
            ImVec2 nsz = mainFont->CalcTextSizeA(nfs, FLT_MAX, 0.0f, nameStr.c_str());
            ImVec2 np(LocationScreen.x - nsz.x * 0.5f, bT - 15.8f);
            if (textBorder) DrawEspTextStroke(d, mainFont, nfs, np, IM_COL32(0,0,0,200), nameStr.c_str());
            d->AddText(mainFont, nfs, np, IM_COL32(255,255,255,255), nameStr.c_str());
        }

        if (imgui::Weapon) {
            std::string wepName = "Fist";
            if (auto wm = p->WeaponManagerComponent) {
                auto slot = wm->GetCurrentUsingPropSlot();
                if ((int)slot.GetValue() >= 1 && (int)slot.GetValue() <= 3)
                    if (auto cw = wm->CurrentWeaponReplicated)
                        wepName = cw->GetWeaponName().ToString();
            }
            const float wfs = 8.5f;
            ImVec2 wsz = mainFont->CalcTextSizeA(wfs, FLT_MAX, 0.0f, wepName.c_str());
            ImVec2 wp(LocationScreen.x - wsz.x * 0.5f, bT - 28.0f-(imgui::Health?32.f*HealthCardScale():0.f));
            if (textBorder) DrawEspTextStroke(d, mainFont, wfs, wp, IM_COL32(0,0,0,200), wepName.c_str());
            d->AddText(mainFont, wfs, wp, IM_COL32(255,210,70,255), wepName.c_str());
        }

        if (imgui::Line && hs.X > 0.f && hs.Y > 0.f && hs.Y < ImGui::GetIO().DisplaySize.y) {
            ImU32 lineColorU32 = boxU32;
            d->AddLine(HudLineOrigin(), ImVec2(hs.X, hs.Y), lineColorU32, lineThickness);
        }

        if (imgui::Bone) DrawSkeletonAdvanced(p, isBot, isVisible);
    }  
    skipBasicESP:;
}
else
{
     
        float totalWidthHalf = 45.0f * asize;
        float barHeight = 12.0f * asize;
        
        float hpHeight = 2.0f * asize;
        

        teamColor(p->TeamID, 200.0f, 160.0f);

ImColor espColor; if (p->bIsAI || p->bEnsure) { if (isVisible) espColor = ImColor(0, 255, 0); else espColor = ImColor(255, 255, 255); } else { if (isVisible) espColor = ImColor(0, 255, 0); else espColor = ImColor(255, 0, 0); }

        float headX = hs.X;
        float headY = hs.Y;
        float nameBoxTop = headY - (35.0f * asize);
        float startX = headX - totalWidthHalf;
        
        float nameBoxBottom = nameBoxTop + barHeight;


if (imgui::Line && hs.X > 0.f && hs.Y > 0.f && hs.Y < ImGui::GetIO().DisplaySize.y) { ImVec2 screenCenter = HudLineOrigin(); bool isVisible = g_PlayerController->LineOfSightTo( g_PlayerController->PlayerCameraManager, p->GetBonePos("Head", {}), true ); ImU32 lineColorU32 = ImGui::GetColorU32(isVisible ? visibleColor : unvisibleColor); d->AddLine( screenCenter, ImVec2(hs.X, hs.Y), lineColorU32, lineThickness ); }

ImVec2 hexCenter{};
if (imgui::Health)  { hexCenter = DrawHealthVnHax(p, d); }
if (imgui::Name && !imgui::Health)DrawPlayerName(p, d, textBorder);
if (imgui::TeamID)    DrawTeamID(p, d, hexCenter, textBorder);
if (imgui::Weapon)    DrawWeaponName(p, d, textBorder);



        if (imgui::Bone) DrawSkeletonAdvanced(p, isBot, isVisible);
}  
    }  

if (imgui::ESP && (imgui::EnemyCount || imgui::EnemyAiming || imgui::Line)) {
    const float scale = ImClamp(ImGui::GetIO().DisplaySize.y / 592.f, .55f, 1.4f);
    DrawMenuHudBadge(ImGui::GetForegroundDrawList(),
                      ImVec2(ImGui::GetIO().DisplaySize.x * .5f, 32.f * scale), 60.f * scale);
}
if (imgui::ESP && imgui::EnemyCount)
    DrawEnemyCounters(totalEnemies1, totalBots1);
DrawEnemyAimingWarning(imgui::ESP && imgui::EnemyAiming && enemyAimingAtUs);


if (imgui::ESP && imgui::GameInfo) {
    DrawGameInfo(); 
                                    }
if (imgui::ESP && imgui::Alert360)
{
    Draw360Alert(cache); 
}

if (Settings::Aimbot::Tick || Enable) {
if (Settings::Aimbot::SilentAimSettings::EnableFov && Cross > 0.0f) {
    DrawFOVCircle(Cross);
}}
if (Settings::Aimbot::Tick || Enable) {
if (Settings::Aimbot::SilentAimSettings::AimingLine) {
    DrawAimingLine();
}}

    ImGui::End();
    ImGui::PopStyleVar();
}

#undef W2S
