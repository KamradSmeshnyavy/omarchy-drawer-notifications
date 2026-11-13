#version 440
// Жидкое стекло (идея — стекло Vitreus, github.com/natepayn3/Vitreus, MIT; код свой). Панель — скруглённый прямоугольник
// толстого стекла поверх обоев: у края линза отклоняет то, что за ним (край увеличивает и подтягивает внутрь), цветные
// каналы отклоняются по-разному (радужная кайма), середина — чистая или матовая (frost — смесь резких и размытых обоев).
// Сверху — ободок светлее сверху-слева, мягкий купол света и блик под курсором. Обои — те же, что на рабочем столе:
// sharpTex / softTex, обрезанные под экран, как PreserveAspectCrop (crop). over 1 — за панелью окно или живые обои:
// преломлять нечего, панель — тонированная плёнка, а размывает Hyprland (layer_rule blur).
// Сборка: qsb --qt6 -o liquidglass.frag.qsb liquidglass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // панель, px
    vec2 screen;    // экран, px
    vec2 origin;    // левый верхний угол панели на экране, px
    vec2 crop;      // видимая доля обоев по x / y
    vec4 tint;      // rgb — цвет стекла, a — сколько его
    vec4 shine;     // xy — блик (px панели), z — сила, w — 1 если курсор над панелью
    float radius;
    float lens;     // ширина линзы у края, px
    float refr;     // сила преломления 0…1
    float disp;     // радуга 0…1
    float frost;    // матовость 0…1
    float rim;      // ободок 0…1
    float dome;     // купол света сверху 0…1
    float over;     // 0 — преломлять обои, 1 — плёнка над окнами
    float alphaOver;// непрозрачность плёнки над окнами
};
layout(binding = 1) uniform sampler2D sharpTex;
layout(binding = 2) uniform sampler2D softTex;

float sdBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 wall(vec2 sp) {
    vec2 uv = (sp / screen - 0.5) * crop + 0.5;
    uv = clamp(uv, vec2(0.001), vec2(0.999));
    return mix(texture(sharpTex, uv).rgb, texture(softTex, uv).rgb, frost);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = size * 0.5;
    float r = min(radius, min(size.x, size.y) * 0.5);
    float d = sdBox(p - c, c, r);
    float mask = clamp(0.5 - d, 0.0, 1.0);
    if (mask <= 0.0) { fragColor = vec4(0.0); return; }

    // нормаль края — градиент расстояния
    float e = 1.0;
    vec2 n = normalize(vec2(sdBox(p - c + vec2(e, 0.0), c, r) - sdBox(p - c - vec2(e, 0.0), c, r),
                            sdBox(p - c + vec2(0.0, e), c, r) - sdBox(p - c - vec2(0.0, e), c, r)) + 1e-5);
    float inside = -d;                                   // 0 на краю, растёт внутрь
    float t = clamp(1.0 - inside / max(lens, 1.0), 0.0, 1.0);
    float bend = t * t * refr * lens * 1.6;              // у самого края сильнее, к середине — ноль

    vec2 sp = origin + p;
    vec3 col;
    if (over < 0.999) {
        vec2 o = -n * bend;
        vec3 rgb = vec3(wall(sp + o * (1.0 + disp * 0.35)).r,
                        wall(sp + o).g,
                        wall(sp + o * (1.0 - disp * 0.35)).b);
        col = mix(rgb, tint.rgb, tint.a);
    } else {
        col = tint.rgb;
    }

    // свет: купол сверху, ободок (ярче сверху-слева), блик под курсором
    float domeL = dome * 0.10 * (1.0 - smoothstep(0.0, size.y * 0.55, p.y));
    float lit = 0.55 + 0.45 * dot(-n, normalize(vec2(-0.55, -0.85)));
    float rimL = rim * (smoothstep(2.2, 0.0, inside) * 0.55 * lit + t * t * 0.10);
    float sh = shine.z * shine.w * exp(-pow(length(p - shine.xy) / (min(size.x, size.y) * 0.45), 2.0)) * 0.16;
    col += vec3(domeL + rimL + sh);

    float a = mix(1.0, alphaOver, over);
    fragColor = vec4(col * a, a) * mask * qt_Opacity;
}
