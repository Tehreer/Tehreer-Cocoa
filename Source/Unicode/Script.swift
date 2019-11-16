//
// Copyright (C) 2019 Muhammad Tayyab Akram
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import SheenBidi

/// Represents the script of a character in Unicode specification. The literals of enum correspond
/// to the script property values defined in
/// [Unicode Standard Annex #24: PropertyValueAliases.txt](https://www.unicode.org/reports/tr24/#Data_File_PVA).
public enum Script: Int {
    /// Script "Inherited".
    case inherited = 0x01

    /// Script "Common".
    case common = 0x02

    /// Script "Unknown".
    case unknown = 0x03

    /// Script "Arabic".
    case arabic = 0x04

    /// Script "Armenian".
    case armenian = 0x05

    /// Script "Bengali".
    case bengali = 0x06

    /// Script "Bopomofo".
    case bopomofo = 0x07

    /// Script "Cyrillic".
    case cyrillic = 0x08

    /// Script "Devanagari".
    case devanagari = 0x09

    /// Script "Georgian".
    case georgian = 0x0A

    /// Script "Greek".
    case greek = 0x0B

    /// Script "Gujarati".
    case gujarati = 0x0C

    /// Script "Gurmukhi".
    case gurmukhi = 0x0D

    /// Script "Hangul".
    case hangul = 0x0E

    /// Script "Han".
    case han = 0x0F

    /// Script "Hebrew".
    case hebrew = 0x10

    /// Script "Hiragana".
    case hiragana = 0x11

    /// Script "Katakana".
    case katakana = 0x12

    /// Script "Kannada".
    case kannada = 0x13

    /// Script "Lao".
    case lao = 0x14

    /// Script "Latin".
    case latin = 0x15

    /// Script "Malayalam".
    case malayalam = 0x16

    /// Script "Oriya".
    case oriya = 0x17

    /// Script "Tamil".
    case tamil = 0x18

    /// Script "Telugu".
    case telugu = 0x19

    /// Script "Thai".
    case thai = 0x1A

    /// Script "Tibetan".
    case tibetan = 0x1B

    /// Script "Braille".
    case braille = 0x1C

    /// Script "Canadian_Aboriginal".
    case canadianAboriginal = 0x1D

    /// Script "Cherokee".
    case cherokee = 0x1E

    /// Script "Ethiopic".
    case ethiopic = 0x1F

    /// Script "Khmer".
    case khmer = 0x20

    /// Script "Mongolian".
    case mongolian = 0x21

    /// Script "Myanmar".
    case myanmar = 0x22

    /// Script "Ogham".
    case ogham = 0x23

    /// Script "Runic".
    case runic = 0x24

    /// Script "Sinhala".
    case sinhala = 0x25

    /// Script "Syriac".
    case syriac = 0x26

    /// Script "Thaana".
    case thaana = 0x27

    /// Script "Yi".
    case yi = 0x28

    /// Script "Deseret".
    case deseret = 0x29

    /// Script "Gothic".
    case gothic = 0x2A

    /// Script "Old_Italic".
    case oldItalic = 0x2B

    /// Script "Buhid".
    case buhid = 0x2C

    /// Script "Hanunoo".
    case hanunoo = 0x2D

    /// Script "Tagbanwa".
    case tagbanwa = 0x2E

    /// Script "Tagalog".
    case tagalog = 0x2F

    /// Script "Cypriot".
    case cypriot = 0x30

    /// Script "Limbu".
    case limbu = 0x31

    /// Script "Linear_B".
    case linearB = 0x32

    /// Script "Osmanya".
    case osmanya = 0x33

    /// Script "Shavian".
    case shavian = 0x34

    /// Script "Tai_Le".
    case taiLe = 0x35

    /// Script "Ugaritic".
    case ugaritic = 0x36

    /// Script "Buginese".
    case buginese = 0x37

    /// Script "Coptic".
    case coptic = 0x38

    /// Script "Glagolitic".
    case glagolitic = 0x39

    /// Script "Kharoshthi".
    case kharoshthi = 0x3A

    /// Script "Syloti_Nagri".
    case sylotiNagri = 0x3B

    /// Script "New_Tai_Lue".
    case newTaiLue = 0x3C

    /// Script "Tifinagh".
    case tifinagh = 0x3D

    /// Script "Old_Persian".
    case oldPersian = 0x3E

    /// Script "Balinese".
    case balinese = 0x3F

    /// Script "Nko".
    case nko = 0x40

    /// Script "Phags_Pa".
    case phagsPa = 0x41

    /// Script "Phoenician".
    case phoenician = 0x42

    /// Script "Cuneiform".
    case cuneiform = 0x43

    /// Script "Carian".
    case carian = 0x44

    /// Script "Cham".
    case cham = 0x45

    /// Script "Kayah_Li".
    case kayahLi = 0x46

    /// Script "Lepcha".
    case lepcha = 0x47

    /// Script "Lycian".
    case lycian = 0x48

    /// Script "Lydian".
    case lydian = 0x49

    /// Script "Ol_Chiki".
    case olChiki = 0x4A

    /// Script "Rejang".
    case rejang = 0x4B

    /// Script "Saurashtra".
    case saurashtra = 0x4C

    /// Script "Sundanese".
    case sundanese = 0x4D

    /// Script "Vai".
    case vai = 0x4E

    /// Script "Imperial_Aramaic".
    case imperialAramaic = 0x4F

    /// Script "Avestan".
    case avestan = 0x50

    /// Script "Bamum".
    case bamum = 0x51

    /// Script "Egyptian_Hieroglyphs".
    case egyptianHieroglyphs = 0x52

    /// Script "Javanese".
    case javanese = 0x53

    /// Script "Kaithi".
    case kaithi = 0x54

    /// Script "Tai_Tham".
    case taiTham = 0x55

    /// Script "Lisu".
    case lisu = 0x56

    /// Script "Meetei_Mayek".
    case meeteiMayek = 0x57

    /// Script "Old_Turkic".
    case oldTurkic = 0x58

    /// Script "Inscriptional_Pahlavi".
    case inscriptionalPahlavi = 0x59

    /// Script "Inscriptional_Parthian".
    case inscriptionalParthian = 0x5A

    /// Script "Samaritan".
    case samaritan = 0x5B

    /// Script "Old_South_Arabian".
    case oldSouthArabian = 0x5C

    /// Script "Tai_Viet".
    case taiViet = 0x5D

    /// Script "Batak".
    case batak = 0x5E

    /// Script "Brahmi".
    case brahmi = 0x5F

    /// Script "Mandaic".
    case mandaic = 0x60

    /// Script "Chakma".
    case chakma = 0x61

    /// Script "Meroitic_Cursive".
    case meroiticCursive = 0x62

    /// Script "Meroitic_Hieroglyphs".
    case meroiticHieroglyphs = 0x63

    /// Script "Miao".
    case miao = 0x64

    /// Script "Sharada".
    case sharada = 0x65

    /// Script "Sora_Sompeng".
    case soraSompeng = 0x66

    /// Script "Takri".
    case takri = 0x67

    /// Script "Caucasian_Albanian".
    case caucasianAlbanian = 0x68

    /// Script "Bassa_Vah".
    case bassaVah = 0x69

    /// Script "Duployan".
    case duployan = 0x6A

    /// Script "Elbasan".
    case elbasan = 0x6B

    /// Script "Grantha".
    case grantha = 0x6C

    /// Script "Pahawh_Hmong".
    case pahawhHmong = 0x6D

    /// Script "Khojki".
    case khojki = 0x6E

    /// Script "Linear_A".
    case linearA = 0x6F

    /// Script "Mahajani".
    case mahajani = 0x70

    /// Script "Manichaean".
    case manichaean = 0x71

    /// Script "Mende_Kikakui".
    case mendeKikakui = 0x72

    /// Script "Modi".
    case modi = 0x73

    /// Script "Mro".
    case mro = 0x74

    /// Script "Old_North_Arabian".
    case oldNorthArabian = 0x75

    /// Script "Nabataean".
    case nabataean = 0x76

    /// Script "Palmyrene".
    case palmyrene = 0x77

    /// Script "Pau_Cin_Hau".
    case pauCinHau = 0x78

    /// Script "Old_Permic".
    case oldPermic = 0x79

    /// Script "Psalter_Pahlavi".
    case psalterPahlavi = 0x7A

    /// Script "Siddham".
    case siddham = 0x7B

    /// Script "Khudawadi".
    case khudawadi = 0x7C

    /// Script "Tirhuta".
    case tirhuta = 0x7D

    /// Script "Warang_Citi".
    case warangCiti = 0x7E

    /// Script "Ahom".
    case ahom = 0x7F

    /// Script "Hatran".
    case hatran = 0x80

    /// Script "Anatolian_Hieroglyphs".
    case anatolianHieroglyphs = 0x81

    /// Script "Old_Hungarian".
    case oldHungarian = 0x82

    /// Script "Multani".
    case multani = 0x83

    /// Script "SignWriting".
    case signwriting = 0x84

    /// Script "Adlam".
    case adlam = 0x85

    /// Script "Bhaiksuki".
    case bhaiksuki = 0x86

    /// Script "Marchen".
    case marchen = 0x87

    /// Script "Newa".
    case newa = 0x88

    /// Script "Osage".
    case osage = 0x89

    /// Script "Tangut".
    case tangut = 0x8A

    /// Script "Masaram_Gondi".
    case masaramGondi = 0x8B

    /// Script "Nushu".
    case nushu = 0x8C

    /// Script "Soyombo".
    case soyombo = 0x8D

    /// Script "Zanabazar_Square".
    case zanabazarSquare = 0x8E

    /// Script "Dogra".
    case dogra = 0x8F

    /// Script "Gunjala_Gondi".
    case gunjalaGondi = 0x90

    /// Script "Makasar".
    case makasar = 0x91

    /// Script "Medefaidrin".
    case medefaidrin = 0x92

    /// Script "Hanifi_Rohingya".
    case hanifiRohingya = 0x93

    /// Script "Sogdian".
    case sogdian = 0x94

    /// Script "Old_Sogdian".
    case oldSogdian = 0x95
}

extension Script {
    /// Returns the OpenType tag of the specified script.
    ///
    /// The association between Unicode Script property and OpenType script tags is taken from the
    /// specification: [https://docs.microsoft.com/en-us/typography/opentype/spec/scripttags](https://docs.microsoft.com/en-us/typography/opentype/spec/scripttags).
    ///
    /// If more than one tag is associated with a script, then the latest one is returned. For
    /// example, Devanagari script has two tags, `deva` and `dev2`. So in this case, `dev2` will be
    /// returned.
    ///
    /// If no tag is associated with a script, then `DFLT` is returned.
    public var openTypeTag: SFNTTag {
        return SFNTTag(rawValue: SBScriptGetOpenTypeTag(SBScript(rawValue)))!
    }
}
