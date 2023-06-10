Pod::Spec.new do |spec|
  spec.name                  = 'TehreerCocoa'
  spec.version               = '3.0'
  spec.summary               = 'Standalone text engine for iOS aimed to be free from platform limitations'

  spec.homepage              = 'https://github.com/Tehreer/Tehreer-Cocoa'
  spec.source                = { :git => 'https://github.com/Tehreer/Tehreer-Cocoa.git',
                                 :tag => 'v3.0',
                                 :submodules => true }

  spec.license               = { :type => 'Apache 2.0' }
  spec.authors               = { 'Muhammad Tayyab Akram' => 'dear_tayyab@yahoo.com' }
  
  spec.platform              = :ios
  spec.ios.deployment_target = '11.0'
  spec.swift_version         = '5.0'

  spec.source_files          = 'Source/**/*.swift',
                               'Libraries/FreeType/src/autofit/autofit.c',
                               'Libraries/FreeType/src/base/ftbase.c',
                               'Libraries/FreeType/src/base/ftbbox.c',
                               'Libraries/FreeType/src/base/ftbitmap.c',
                               'Libraries/FreeType/src/base/ftdebug.c',
                               'Libraries/FreeType/src/base/ftgasp.c',
                               'Libraries/FreeType/src/base/ftglyph.c',
                               'Libraries/FreeType/src/base/ftinit.c',
                               'Libraries/FreeType/src/base/ftmm.c',
                               'Libraries/FreeType/src/base/ftpatent.c',
                               'Libraries/FreeType/src/base/ftstroke.c',
                               'Libraries/FreeType/src/base/ftsynth.c',
                               'Libraries/FreeType/src/base/ftsystem.c',
                               'Libraries/FreeType/src/bdf/bdf.c',
                               'Libraries/FreeType/src/cff/cff.c',
                               'Libraries/FreeType/src/cid/type1cid.c',
                               'Libraries/FreeType/src/gzip/ftgzip.c',
                               'Libraries/FreeType/src/lzw/ftlzw.c',
                               'Libraries/FreeType/src/pcf/pcf.c',
                               'Libraries/FreeType/src/pfr/pfr.c',
                               'Libraries/FreeType/src/psaux/psaux.c',
                               'Libraries/FreeType/src/pshinter/pshinter.c',
                               'Libraries/FreeType/src/psnames/psnames.c',
                               'Libraries/FreeType/src/raster/raster.c',
                               'Libraries/FreeType/src/sdf/sdf.c',
                               'Libraries/FreeType/src/sfnt/sfnt.c',
                               'Libraries/FreeType/src/smooth/smooth.c',
                               'Libraries/FreeType/src/svg/svg.c',
                               'Libraries/FreeType/src/truetype/truetype.c',
                               'Libraries/FreeType/src/type1/type1.c',
                               'Libraries/FreeType/src/type42/type42.c',
                               'Libraries/FreeType/src/winfonts/winfnt.c',
                               'Libraries/HarfBuzz/src/harfbuzz.cc',
                               'Libraries/Patch/*.c',
                               'Libraries/SheenBidi/Source/SheenBidi.c',
                               'Libraries/UniBreak/src/emojidef.c',
                               'Libraries/UniBreak/src/graphemebreak.c',
                               'Libraries/UniBreak/src/linebreak.c',
                               'Libraries/UniBreak/src/linebreakdata.c',
                               'Libraries/UniBreak/src/linebreakdef.c',
                               'Libraries/UniBreak/src/unibreakbase.c',
                               'Libraries/UniBreak/src/unibreakdef.c',
                               'Libraries/UniBreak/src/wordbreak.c'
  spec.preserve_paths        = 'Libraries/FreeType/include/**/*.h',
                               'Libraries/FreeType/src/**/*.{h,c}',
                               'Libraries/HarfBuzz/src/*.{h,hh,cc}',
                               'Libraries/Patch/*.{h,c}',
                               'Libraries/SheenBidi/Headers/*.h',
                               'Libraries/SheenBidi/Source/**/*.{h,c}',
                               'Libraries/UniBreak/src/*.{h,c}',
                               'Libraries/module.modulemap'

  spec.pod_target_xcconfig   = {
    'GCC_PREPROCESSOR_DEFINITIONS' => [
      'FT2_BUILD_LIBRARY',
      'HAVE_FREETYPE',
      'HAVE_FT_GET_VAR_BLEND_COORDINATES',
      'HAVE_FT_DONE_MM_VAR',
      'SB_CONFIG_UNITY',
    ],
    'HEADER_SEARCH_PATHS' => [
      '"${PODS_TARGET_SRCROOT}/Libraries/FreeType/include"',
      '"${PODS_TARGET_SRCROOT}/Libraries/HarfBuzz/src"',
      '"${PODS_TARGET_SRCROOT}/Libraries/SheenBidi/Headers"',
      '"${PODS_TARGET_SRCROOT}/Libraries/UniBreak/src"'
    ],
    'SWIFT_INCLUDE_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/Libraries"',
      '"${PODS_TARGET_SRCROOT}/Libraries/FreeType/include"',
      '"${PODS_TARGET_SRCROOT}/Libraries/HarfBuzz/src"',
      '"${PODS_TARGET_SRCROOT}/Libraries/SheenBidi/Headers"',
      '"${PODS_TARGET_SRCROOT}/Libraries/UniBreak/src"'
    ]
  }

  spec.compiler_flags        = '-w'
  spec.framework             = 'CoreGraphics', 'Foundation', 'QuartzCore', 'UIKit'

end
