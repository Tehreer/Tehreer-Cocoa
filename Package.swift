// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TehreerCocoa",
    platforms: [.iOS(.v11)],
    products: [
        .library(
            name: "TehreerCocoa",
            targets: ["TehreerCocoa"]
        )
    ],
    targets: [
        .target(
            name: "Libraries",
            path: "Libraries",
            sources: [
                "FreeType/src/autofit/autofit.c",
                "FreeType/src/base/ftbase.c",
                "FreeType/src/base/ftbbox.c",
                "FreeType/src/base/ftbitmap.c",
                "FreeType/src/base/ftdebug.c",
                "FreeType/src/base/ftgasp.c",
                "FreeType/src/base/ftglyph.c",
                "FreeType/src/base/ftinit.c",
                "FreeType/src/base/ftmm.c",
                "FreeType/src/base/ftpatent.c",
                "FreeType/src/base/ftstroke.c",
                "FreeType/src/base/ftsynth.c",
                "FreeType/src/base/ftsystem.c",
                "FreeType/src/bdf/bdf.c",
                "FreeType/src/cff/cff.c",
                "FreeType/src/cid/type1cid.c",
                "FreeType/src/gzip/ftgzip.c",
                "FreeType/src/lzw/ftlzw.c",
                "FreeType/src/pcf/pcf.c",
                "FreeType/src/pfr/pfr.c",
                "FreeType/src/psaux/psaux.c",
                "FreeType/src/pshinter/pshinter.c",
                "FreeType/src/psnames/psnames.c",
                "FreeType/src/raster/raster.c",
                "FreeType/src/sdf/sdf.c",
                "FreeType/src/sfnt/sfnt.c",
                "FreeType/src/smooth/smooth.c",
                "FreeType/src/svg/svg.c",
                "FreeType/src/truetype/truetype.c",
                "FreeType/src/type1/type1.c",
                "FreeType/src/type42/type42.c",
                "FreeType/src/winfonts/winfnt.c",
                "HarfBuzz/src/harfbuzz.cc",
                "SheenBidi/Source/SheenBidi.c",
                "UniBreak/src/emojidef.c",
                "UniBreak/src/graphemebreak.c",
                "UniBreak/src/linebreak.c",
                "UniBreak/src/linebreakdata.c",
                "UniBreak/src/linebreakdef.c",
                "UniBreak/src/unibreakbase.c",
                "UniBreak/src/unibreakdef.c",
                "UniBreak/src/wordbreak.c",
                "module.modulemap"
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("FreeType/include"),
                .headerSearchPath("SheenBidi/Headers"),
                .define("FT2_BUILD_LIBRARY"),
                .define("HAVE_FREETYPE"),
                .define("HAVE_FT_GET_VAR_BLEND_COORDINATES"),
                .define("HAVE_FT_DONE_MM_VAR"),
                .define("SB_CONFIG_UNITY")
            ]
        ),
        .target(
            name: "TehreerCocoa",
            dependencies: ["Libraries"],
            path: "Source",
            cSettings: [
                .headerSearchPath("../Libraries/FreeType/include")
            ]
        )
    ],
    cxxLanguageStandard: .cxx11
)
