// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TehreerCocoa",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "TehreerCocoa",
            targets: ["TehreerCocoa"]
        )
    ],
    targets: [
        .target(
            name: "FreeType",
            path: "Libraries/FreeType",
            exclude: ["include/module.modulemap"],
            sources: [
                "src/autofit/autofit.c",
                "src/base/ftbase.c",
                "src/base/ftbbox.c",
                "src/base/ftbitmap.c",
                "src/base/ftdebug.c",
                "src/base/ftgasp.c",
                "src/base/ftglyph.c",
                "src/base/ftinit.c",
                "src/base/ftmm.c",
                "src/base/ftpatent.c",
                "src/base/ftstroke.c",
                "src/base/ftsynth.c",
                "src/base/ftsystem.c",
                "src/bdf/bdf.c",
                "src/cff/cff.c",
                "src/cid/type1cid.c",
                "src/gzip/ftgzip.c",
                "src/lzw/ftlzw.c",
                "src/pcf/pcf.c",
                "src/pfr/pfr.c",
                "src/psaux/psaux.c",
                "src/pshinter/pshinter.c",
                "src/psnames/psnames.c",
                "src/raster/raster.c",
                "src/sdf/sdf.c",
                "src/sfnt/sfnt.c",
                "src/smooth/smooth.c",
                "src/svg/svg.c",
                "src/truetype/truetype.c",
                "src/type1/type1.c",
                "src/type42/type42.c",
                "src/winfonts/winfnt.c",
                "include"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("FT2_BUILD_LIBRARY")
            ]
        ),
        .target(
            name: "SheenBidi",
            path: "Libraries/SheenBidi",
            sources: [
                "Source/SheenBidi.c"
            ],
            publicHeadersPath: "Headers",
            cSettings: [
                .define("SB_CONFIG_UNITY")
            ]
        ),
        .target(
            name: "UniBreak",
            path: "Libraries/UniBreak",
            sources: [
                "src/emojidef.c",
                "src/graphemebreak.c",
                "src/linebreak.c",
                "src/linebreakdata.c",
                "src/linebreakdef.c",
                "src/unibreakbase.c",
                "src/unibreakdef.c",
                "src/wordbreak.c"
            ],
            publicHeadersPath: "src"
        ),
        .target(
            name: "HarfBuzz",
            dependencies: ["FreeType"],
            path: "Libraries/HarfBuzz",
            sources: [
                "src/harfbuzz.cc"
            ],
            publicHeadersPath: "src",
            cxxSettings: [
                .define("HAVE_FREETYPE"),
                .define("HAVE_FT_GET_VAR_BLEND_COORDINATES"),
                .define("HAVE_FT_DONE_MM_VAR")
            ]
        ),
        .target(
            name: "TehreerCocoa",
            dependencies: ["FreeType", "HarfBuzz", "SheenBidi", "UniBreak"],
            path: "Source"
        ),
        .testTarget(
            name: "TehreerCocoaTests",
            dependencies: ["TehreerCocoa"],
            path: "Tests"
        )
    ],
    swiftLanguageModes: [.v6],
    cxxLanguageStandard: .cxx11
)
