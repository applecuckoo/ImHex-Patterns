#pragma author Shimogawa (aka Rebuild), applecuckoo
#pragma description TrueType/OpenType font
#pragma endian big
#pragma MIME font/ttf
#pragma MIME font/otf

#pragma pattern_limit 1000000

import std.mem;
import std.string;
import std.time;
import std.io;
import type.magic;

struct TableDirectory {
    char tag[4];
    u32 checkSum;
    u32 offset;
    u32 length;
};

fn format_fixed32(auto fp32) {
    return fp32.integer + fp32.fraction / 65536.0;
};

fn format_f2dot14(auto f) {
    return f.integer + f.fraction / 16384.0;
};

using FWord = s16;
using UFWord = u16;

struct FixedPoint32 {
    u16 integer;
    u16 fraction;
} [[format("format_fixed32")]];

bitfield F2Dot14 {
    integer : 2;
    fraction : 14;
} [[format("format_f2dot14")]];

fn format_longdatetime(auto t) {
    return std::time::format(std::time::to_utc(u32(t.time - 2082844800)));
};

struct LongDatetime {
    s64 time;
} [[format("format_longdatetime")]];

u64 currentOffset;
u64 currentLength;
u64 glyfStart;
bool hasPostScriptOutlines = false;
u16 numHMetrics;
u16 gNumGlyphs;
u16 numOfLongVerMetrics;
s16 indexToLocFormat;

// begin layout common table formats

using GDEFGlyphClasses;

struct ClassRange<auto tableString> {
    u16 startGlyphID, endGlyphID;
    if (tableString == "GDEF")
        GDEFGlyphClasses class;
    else
        u16 class;
};

struct ClassDefFormat<auto tableString> {
    u16 format;
    if (format == 1) {
        u16 startGlyphID, glyphCount;
        u16 classValues[glyphCount];
    } if (format == 2) {
        u16 classRangeCount;
        ClassRange<tableString> classRangeRecords[classRangeCount];
    }
};

// end layout common table formats

// begin avar

struct AxisValueMap {
    F2Dot14 fromCoord;
    F2Dot14 toCoord;
};

struct ShortFracSegment {
    u16 positionMapCount;
    AxisValueMap axisValueMaps[positionMapCount];
};

struct AvarTable {
    FixedPoint32 version;
    s32 axisCount;
    ShortFracSegment segments[axisCount];
};

// end avar

// begin cmap

u64 startOfCmapTable = 0;

struct BaseCmapSubtable {
    u64 start = $;
    u16 format;
};

struct CmapSubtable0 : BaseCmapSubtable {
    u16 length;
    u16 language;
    u8 glyphIndexArr[256];
};

struct CmapSubtable2 : BaseCmapSubtable {
    u16 length;
    u16 language;
    u16 subHeaderKeys[256];
    u8 data[length - 516];
};

struct CmapSubtable4 : BaseCmapSubtable {
    u16 length;
    u64 end = start + length;
    u16 language;
    u16 segCountX2;
    u16 segCount = segCountX2 / 2;
    u16 searchRange;
    u16 entrySelector;
    u16 rangeShift;
    u16 endCode[segCount];
    u16 reserved;
    u16 startCode[segCount];
    s16 idDelta[segCount];
    u16 idRangeOffset[segCount];
    u16 glyphIdArr[(end - $) / sizeof(u16)];
};

struct CmapSubtable6 : BaseCmapSubtable {
    u16 length;
    u16 language;
    u16 firstCode;
    u16 entryCount;
    u16 glyphIdArr[entryCount];
};

struct SequentialMapGroup {
    u32 startCharCode;
    u32 endCharCode;
    u32 startGlyphId;
};

struct CmapSubtable8 : BaseCmapSubtable {
    u16 reserved;
    u32 length;
    u32 language;
    u8 is32[8192];
    u32 numGroups;
    SequentialMapGroup groups[numGroups];
};

struct CmapSubtable10 : BaseCmapSubtable {
    u16 reserved;
    u32 length;
    u64 end = start + length;
    u32 language;
    u32 startCharCode;
    u32 numChars;
    u16 glyphIdArr[(end - $) / sizeof(u16)];
};

struct CmapSubtable12 : BaseCmapSubtable {
    u16 reserved;
    u32 length;
    u32 language;
    u32 numGroups;
    SequentialMapGroup groups[numGroups];
};

struct CmapSubtable {
    u16 format = std::mem::read_unsigned($, 2, std::mem::Endian::Big);

    match (format) {
        (0): CmapSubtable0 table [[inline]];
        (2): CmapSubtable2 table [[inline]];
        (4): CmapSubtable4 table [[inline]];
        (6): CmapSubtable6 table [[inline]];
        (8): CmapSubtable8 table [[inline]];
        (10): CmapSubtable10 table [[inline]];
        (12): CmapSubtable12 table [[inline]];
        (_): BaseCmapSubtable table [[inline]];
    }
} [[name(std::format("Subtable Format {}", format))]];

enum CmapPlatform : u16 {
    Unicode = 0,
    Macintosh = 1,
    ISO = 2,
    Microsoft = 3,
    Custom = 4,
};

struct EncodingRecord {
    CmapPlatform platformId;
    u16 encodingId;
    u32 offset;

    CmapSubtable subtable @ startOfCmapTable + offset;
};

struct CmapTable {
    startOfCmapTable = $;
    u16 version;
    u16 numSubtables;
    EncodingRecord encodingRecords[numSubtables];
};

// end cmap

// begin colr

enum PaintFormat : u8 {
    PaintColrLayers = 1,
    PaintSolid,
    PaintVarSolid,
    PaintLinearGradient,
    PaintVarLinearGradient,
    PaintRadialGradient,
    PaintVarRadialGradient,
    PaintSweepGradient,
    PaintVarSweepGradient,
    PaintGlyph,
    PaintColrGlyph,
    PaintTransform,
    PaintVarTransform,
    PaintTranslate,
    PaintVarTranslate,
    PaintScale,
    PaintVarScale,
    PaintScaleAroundCenter,
    PaintVarScaleAroundCenter,
    PaintScaleUniform,
    PaintVarScaleUniform,
    PaintScaleUniformAroundCenter,
    PaintVarScaleUniformAroundCenter,
    PaintRotate,
    PaintVarRotate,
    PaintRotateAroundCenter,
    PaintVarRotateAroundCenter,
    PaintSkew,
    PaintVarSkew,
    PaintSkewAroundCenter,
    PaintVarSkewAroundCenter,
    PaintComposite
};

struct PaintColrLayer {
    u8 numLayers;
    u32 firstLayerIndex;
};

struct PaintSolid {
    u16 paletteIndex;
    F2Dot14 alpha;
};

struct PaintVarSolid : PaintSolid {
    u32 varIndexBase;
};

struct ColorStop {
    F2Dot14 stopOffset;
    u16 paletteIndex;
    F2Dot14 alpha;
};

struct VarColorStop : ColorStop {
    u32 varIndexBase;
};

enum Extend : u8 {
    EXTEND_PAD,
    EXTEND_REPEAT,
    EXTEND_REFLECT
};

struct ColorLine<auto var> {
    Extend extend;
    u16 numStops;
    if (var == true)
        VarColorStop colorStops[numStops];
    else
        ColorStop colorStops[numStops];
};

struct PaintLinearGradient<auto var> {
    u24 colorLineOffset;
    ColorLine<var> colorLine @ parent.startOfPaint + colorLineOffset;
    FWord x0, y0, x1, y1, x2, y2;
    if (var == true)
        u32 varIndexBase;
};

struct PaintRadialGradient<auto var> {
    u24 colorLineOffset;
    ColorLine<var> colorLine @ parent.startOfPaint + colorLineOffset;
    FWord x0, y0;
    UFWord radius0;
    FWord x1, y1;
    UFWord radius1;
    if (var == true)
        u32 varIndexBase;
};

struct PaintSweepGradient<auto var> {
    u24 colorLineOffset;
    ColorLine<var> colorLine @ parent.startOfPaint + colorLineOffset;
    FWord centerX, centerY;
    F2Dot14 startAngle, endAngle;
    if (var == true)
        u32 varIndexBase;
};

using Paint;

struct PaintGlyph {
    u24 paintOffset;
    u16 glyphID;
    Paint paint @ parent.startOfPaint + paintOffset;
};

struct PaintColrGlyph {
    u16 glyphID;
};

struct Affine2x3<auto var> {
    FixedPoint32 xx, yx, xy, yy, dx, dy;
    if (var == true)
        u32 varIndexBase;
};

struct PaintTransform<auto var> {
    u24 paintOffset, transformOffset;
    Paint paint @ parent.startOfPaint + paintOffset;
    Affine2x3<var> transform @ parent.startOfPaint + transformOffset;
};

struct PaintTranslate<auto var> {
    u24 paintOffset;
    FWord dx, dy;
    if (var == true)
        u32 varIndexBase;
    Paint paint @ parent.startOfPaint + paintOffset;
};

struct PaintScale<auto var, auto aroundCenter, auto uniform> {
    // combined format to cover formats 16-23
    u24 paintOffset;
    if (uniform == true)
        F2Dot14 scale;
    else
        F2Dot14 scaleX, scaleY;
    if (aroundCenter == true)
        FWord centerX, centerY;
    if (var == true)
        u32 varIndexBase;
    Paint paint @ parent.startOfPaint + paintOffset;
};

struct PaintRotate<auto var, auto aroundCenter> {
    u24 paintOffset;
    F2Dot14 angle;
    if (aroundCenter == true)
        FWord centerX, centerY;
    if (var == true)
        u32 varIndexBase;
    Paint paint @ parent.startOfPaint + paintOffset;
};

struct PaintSkew<auto var, auto aroundCenter> {
    u24 paintOffset;
    F2Dot14 xSkewAngle, ySkewAngle;
    if (aroundCenter == true)
        FWord centerX, centerY;
    if (var == true)
        u32 varIndexBase;
    Paint paint @ parent.startOfPaint + paintOffset;
};

enum CompositeMode : u8 {
    COMPOSITE_CLEAR,
    COMPOSITE_SRC,
    COMPOSITE_DEST,
    COMPOSITE_SRC_OVER,
    COMPOSITE_DEST_OVER,
    COMPOSITE_SRC_IN,
    COMPOSITE_DEST_IN,
    COMPOSITE_SRC_OUT,
    COMPOSITE_DEST_OUT,
    COMPOSITE_SRC_ATOP,
    COMPOSITE_DEST_ATOP,
    COMPOSITE_XOR,
    COMPOSITE_PLUS,
    COMPOSITE_SCREEN,
    COMPOSITE_OVERLAY,
    COMPOSITE_DARKEN,
    COMPOSITE_LIGHTEN,
    COMPOSITE_COLOR_DODGE,
    COMPOSITE_COLOR_BURN,
    COMPOSITE_HARD_LIGHT,
    COMPOSITE_SOFT_LIGHT,
    COMPOSITE_DIFFERENCE,
    COMPOSITE_EXCLUSION,
    COMPOSITE_MULTIPLY,
    COMPOSITE_HSL_HUE,
    COMPOSITE_HSL_SATURATION,
    COMPOSITE_HSL_COLOR,
    COMPOSITE_HSL_LUMINOSITY
};

struct PaintComposite {
    u24 sourcePaintOffset;
    CompositeMode compositeMode;
    u24 backdropPaintOffset;
    Paint sourcePaint @ parent.startOfPaint + sourcePaintOffset;
    Paint backdropPaint @ parent.startOfPaint + backdropPaintOffset;
    
};

struct Paint {
    u64 startOfPaint = $;
    PaintFormat paintFormat;
    match (paintFormat) {
        (PaintFormat::PaintColrLayers): PaintColrLayer paint;
        (PaintFormat::PaintSolid): PaintSolid paint;
        (PaintFormat::PaintVarSolid): PaintVarSolid paint;
        (PaintFormat::PaintLinearGradient): PaintLinearGradient<false> paint;
        (PaintFormat::PaintVarLinearGradient): PaintLinearGradient<true> paint;
        (PaintFormat::PaintRadialGradient): PaintRadialGradient<false> paint;
        (PaintFormat::PaintVarRadialGradient): PaintRadialGradient<true> paint;
        (PaintFormat::PaintSweepGradient): PaintSweepGradient<false> paint;
        (PaintFormat::PaintVarSweepGradient): PaintSweepGradient<true> paint;
        (PaintFormat::PaintGlyph): PaintGlyph paint;
        (PaintFormat::PaintColrGlyph): PaintColrGlyph paint;
        (PaintFormat::PaintTransform): PaintTransform<false> paint;
        (PaintFormat::PaintVarTransform): PaintTransform<true> paint;
        (PaintFormat::PaintTranslate): PaintTranslate<false> paint;
        (PaintFormat::PaintVarTranslate): PaintTranslate<true> paint;
        (PaintFormat::PaintScale): PaintScale<false, false, false> paint;
        (PaintFormat::PaintVarScale): PaintScale<true, false, false> paint;
        (PaintFormat::PaintScaleAroundCenter): PaintScale<false, true, false> paint;
        (PaintFormat::PaintVarScaleAroundCenter): PaintScale<true, true, false> paint;
        (PaintFormat::PaintScaleUniform): PaintScale<false, false, true> paint;
        (PaintFormat::PaintVarScaleUniform): PaintScale<true, false, true> paint;
        (PaintFormat::PaintScaleUniformAroundCenter): PaintScale<false, true, true> paint;
        (PaintFormat::PaintVarScaleUniformAroundCenter): PaintScale<true, true, true> paint;
        (PaintFormat::PaintRotate): PaintRotate<false, false> paint;
        (PaintFormat::PaintVarRotate): PaintRotate<true, false> paint;
        (PaintFormat::PaintRotateAroundCenter): PaintRotate<false, true> paint;
        (PaintFormat::PaintVarRotateAroundCenter): PaintRotate<true, true> paint;
        (PaintFormat::PaintSkew): PaintSkew<false, false> paint;
        (PaintFormat::PaintVarSkew): PaintSkew<true, false> paint;
        (PaintFormat::PaintSkewAroundCenter): PaintSkew<false, true> paint;
        (PaintFormat::PaintVarSkewAroundCenter): PaintSkew<true, true> paint;
        (PaintFormat::PaintComposite): PaintComposite paint;
    }
};

struct BaseGlyph {
    u16 glyphID, firstLayerIndex, numLayers;
};

struct LayerRecord {
    u16 glyphID, paletteIndex;
};

struct BaseGlyphPaintRecord {
    u16 glyphID;
    u32 paintOffset;
    // yes, this isn't the best way to read each paint table.
    // in most cases a paint table will be used more than once,
    // so the pattern will redundantly re-decode the paint table.
    // feel free to contribute better solutions if you'd like!
    Paint paintRecord @ parent.startOfBaseGlyphList + paintOffset;
};

struct BaseGlyphList {
    u64 startOfBaseGlyphList = $;
    u32 numBaseGlyphPaintRecords;
    BaseGlyphPaintRecord baseGlyphPaintRecords[numBaseGlyphPaintRecords];
};

struct Layer {
    u32 paintOffset;
    // see above note regarding reading paint tables redundantly
    Paint paint @ parent.startOfLayerList + paintOffset;
};

struct LayerList {
    u64 startOfLayerList = $;
    u32 numLayers;
    Layer layers[numLayers];
};

struct ClipBox {
    u8 format;
    // both format 1 and format 2 contain these values
    // format 2 is for variable fonts, hence the extra index
    FWord xMin, yMin, xMax, yMax;
    if (format == 2)
        u32 varIndexBase;
};

struct Clip {
    u16 startGlyphID, endGlyphID;
    u24 clipBoxOffset;
};

struct ClipList {
    u8 format;
    u32 numClips;
    Clip clips[numClips];
};

struct ColrTable {
    u64 startOfColrTable = $;
    u16 version, numBaseGlyphRecords;
    u32 baseGlyphRecordsOffset, layerRecordsOffset;
    u16 numLayerRecords;
    if (baseGlyphRecordsOffset != 0)
        BaseGlyph baseGlyphs[numBaseGlyphRecords];
    if (layerRecordsOffset != 0)
        LayerRecord layerRecords[numBaseGlyphRecords];
    if (version == 1) {
        u32 baseGlyphListOffset, layerListOffset, clipListOffset, varIndexMapOffset, itemVariationStoreOffset;
        BaseGlyphList baseGlyphList @ startOfColrTable + baseGlyphListOffset;
        if (layerListOffset != 0)
            LayerList layerList @ startOfColrTable + layerListOffset;
        if (clipListOffset != 0)
            ClipList clipList @ startOfColrTable + clipListOffset;
    }
    
};

// end colr

// begin cpal

struct ColorRecord {
    u8 blue, green, red, alpha;
}[[hex::inline_visualize("color", red, green, blue, alpha)]];

struct CpalTable {
    u64 startOfCpalTable = $;
    u16 version;
    u16 numPaletteEntries;
    u16 numPalettes;
    u16 numColorRecords;
    u32 colorRecordsArrayOffset;
    u16 colorRecordIndices[numPalettes];
    if (version == 1) {
        u32 paletteTypesArrayOffset;
        u32 paletteLabelsArrayOffset;
        u32 paletteEntryLabelsArrayOffset;
    }
    ColorRecord colorRecords[numColorRecords] @ startOfCpalTable + colorRecordsArrayOffset;
};

// end cpal

// begin cvt

struct CvtTable {
    u64 size = currentLength / sizeof(FWord);
    FWord controlValues[size];
};

// end cvt

// begin DSIG

bitfield DSIGFlags {
    padding: 15;
    unresignable : 1;
};

struct SignatureBlock1 {
    padding[4];
    u32 signatureLength;
    u8 signature[signatureLength];
};

struct SignatureRecord {
    u32 format, length, signatureBlockOffset;
    SignatureBlock1 signatureBlock @ parent.startOfDSIGTable + signatureBlockOffset;
};

struct DSIGTable {
    u64 startOfDSIGTable  = $;
    u32 version;
    u16 numSignatures;
    DSIGFlags flags;
    SignatureRecord signatureRecords[numSignatures];
};

// end DSIG

// begin FFTM

// custom table defined by FontForge for timestamp metadata
// defined at https://fontforge.org/docs/techref/non-standard.html

struct FFTMTable {
    u32 version;
    LongDatetime FontForgeTimeStamp, fontCreated, fontLastModified;
};

// end FFTM

// begin gasp

bitfield RangeGaspBehavior {
    padding : 12;
    symmetricSmoothing : 1;
    symmetricGridfit : 1;
    doGray : 1;
    gridFit : 1;
};

struct GaspRange {
    u16 rangeMaxPPEM;
    RangeGaspBehavior rangeGaspBehavior;
};

struct GaspTable {
    u16 version;
    u16 numRanges;
    GaspRange gaspRanges[numRanges];
};

// end gasp

// start gdef

enum GDEFGlyphClasses : u16 {
    BASE_GLYPH = 1,
    LIGATURE_GLYPH,
    MARK_GLYPH,
    COMPONENT_GLYPH
};

struct AttachPoint {
    u16 pointCount;
    u16 pointIndices[pointCount];
};

//struct AttachPoint

struct AttachList {
    u64 startOfAttachList = $;
    u16 coverageOffset, glyphCount;
    
};

struct GDEFTable {
    u64 startOfGDEFTable = $;
    u16 majorVersion, minorVersion, glyphClassDefOffset, attachListOffset, ligCaretListOffset, markAttachClassDefOffset;
    
    if (glyphClassDefOffset != 0)
        ClassDefFormat<"GDEF"> glyphClassDef @ startOfGDEFTable + glyphClassDefOffset;
    if (attachListOffset != 0)
        AttachList attachList @ startOfGDEFTable + attachListOffset;
    // this is a cheeky version check, it doesn't account for any major version increases
    if (minorVersion >= 2)
        u16 markGlyphSetsDefOffset;
    if (minorVersion >= 3)
        u32 itemVarStoreOffset;
};

// end gdef

// begin glyf

struct GlyphTableHeader {
    u64 startOffset = $;
    s16 numContours;
    FWord xMin;
    FWord yMin;
    FWord xMax;
    FWord yMax;
};

bitfield OutlineFlag {
    padding : 2;
    ySameOrPositive : 1;
    xSameOrPositive : 1;
    repeat : 1;
    yShort : 1;
    xShort : 1;
    onCurve : 1;
};

u32 pIdx = 0;
u32 curGlyfSize;

struct SimpleGlyphFlag {
    pIdx += 1;
    OutlineFlag flag;
    if (flag.repeat) {
        pIdx += 1;
        u8 repeatTimes;
    }
};

struct SimpleGlyphTable : GlyphTableHeader {
    u16 endPtsOfContours[numContours];
    u32 numPoints = numContours == 0 ? 0 : endPtsOfContours[numContours - 1];
    u16 instructionLength;
    u8 instructions[instructionLength];
    pIdx = 0;
    SimpleGlyphFlag flags[while(pIdx < numPoints)] [[single_color]];
    u8 data[startOffset + curGlyfSize - $];
};

bitfield CompositeGlyphFlag {
    padding : 3;
    unscaledComponentOffset : 1;
    scaledComponentOffset : 1;
    overlapCompound : 1;
    useMyMetrics : 1;
    weHaveInstructions : 1;
    weHaveA2x2 : 1;
    weHaveAnXAndYScale : 1;
    moreComponents : 1;
    padding : 1;
    weHaveAScale : 1;
    roundXYToGrid : 1;
    argsAreXYValues : 1;
    arg1And2AreWords : 1;
};

bool componentGlyphHasMoreComponents;
bool componentGlyphHasInstruction;

struct ComponentGlyphRecord {
    CompositeGlyphFlag flags;
    u16 glyphIndex;
    if (flags.arg1And2AreWords) {
        FWord arg1;
        FWord arg2;
    } else {
        u8 arg1;
        u8 arg2;
    }
    if (flags.weHaveAScale) {
        F2Dot14 scale;
    } else if (flags.weHaveAnXAndYScale) {
        F2Dot14 xScale;
        F2Dot14 yScale;
    } else if (flags.weHaveA2x2) {
        F2Dot14 xScale;
        F2Dot14 scale01;
        F2Dot14 scale10;
        F2Dot14 yScale;
    }
    componentGlyphHasMoreComponents = flags.moreComponents;
    componentGlyphHasInstruction = flags.weHaveInstructions;
};

struct CompositeGlyphTable : GlyphTableHeader {
    componentGlyphHasMoreComponents = true;
    componentGlyphHasInstruction = false;
    ComponentGlyphRecord records[while (componentGlyphHasMoreComponents)];
    if (componentGlyphHasInstruction) {
        u16 instructionLength;
        u8 instructions[instructionLength];
    }
};

struct GlyfTable {
    s16 type = std::mem::read_signed($, 2, std::mem::Endian::Big);

    if (type >= 0) {
        SimpleGlyphTable table [[inline]];
    } else {
        CompositeGlyphTable table [[inline]];
    }
} [[name(std::format("glyf ({})", table.numContours < 0 ? "Composite" : "Simple"))]];

// end glyf

// begin hdmx

struct DeviceRecord {
    u8 pixelSize;
    u8 maxWidth;
    u8 widths[gNumGlyphs];
};

struct HdmxTable {
    u16 version;
    u16 numRecords;
    u32 sizeDeviceRecord;
    DeviceRecord records[numRecords];
};

// end hdmx

// begin head

bitfield HeadFlag {
    padding : 1;
    lastResort : 1;
    clearTypeOptimized : 1;
    converted : 1;
    lossless : 1;
    indicStyleRearr : 1;
    RTLGlyph : 1;
    AATFont : 1;
    linguisticRender : 1;
    padding : 1;
    verticalLayout : 1;
    instrMayAlterAW : 1;
    integerScaling : 1;
    differentPointSize : 1;
    xLBlackBitIsLSB : 1;
    yZeroIsBaseline : 1;
};

bitfield MacStyle {
    padding : 9;
    extended : 1;
    condensed : 1;
    shadow : 1;
    outline : 1;
    underline : 1;
    italic : 1;
    bold : 1;
};

struct HeadTable {
    FixedPoint32 version;
    FixedPoint32 fontRevision;
    u32 checksumAdjustment;
    type::Magic<"\x5f\x0f\x3c\xf5"> magicNumber;
    HeadFlag flags;
    u16 unitsPerEm;
    LongDatetime created;
    LongDatetime modified;
    FWord xMin;
    FWord yMin;
    FWord xMax;
    FWord yMax;
    MacStyle macStyle;
    u16 lowestRecPPEM;
    s16 fontDirectionHint;
    s16 indexToLocFormat;
    s16 glyphDataFormat;
};

// end head

// begin hhea

struct HheaTable {
    FixedPoint32 version;
    FWord ascent;
    FWord descent;
    FWord lineGap;
    UFWord advanceWidthMax;
    FWord minLeftSideBearing;
    FWord minRightSideBearing;
    FWord xMaxExtent;
    s16 caretSlopeRise;
    s16 caretSlopeRun;
    s16 caretOffset;
    s16 reserved[4];
    s16 metricDataFormat;
    u16 numberOfHMetrics;
    numHMetrics = numberOfHMetrics;
};

// end hhea

// begin hmtx

struct LongHorMetric {
    UFWord advanceWidth;
    FWord lsb;
};

struct HmtxTable {
    LongHorMetric hMetrics[numHMetrics];
    FWord leftSideBearings[gNumGlyphs - numHMetrics];
};

// end hmtx

// begin loca

// loca contains offsets for glyf tables, so
// we put glyf arrays here also.

struct GlyfWithOffset<auto longOffset> {
    if (longOffset) {
        u32 offset;
        u32 realOffset = offset;
        u32 nextOff = std::mem::read_unsigned($, 4, std::mem::Endian::Big);
    } else {
        u16 offset;
        u32 realOffset = u32(offset) * 2;
        u32 nextOff = u32(std::mem::read_unsigned($, 2, std::mem::Endian::Big)) * 2;
    }
    curGlyfSize = nextOff - realOffset;
    if (curGlyfSize != 0) {
        GlyfTable glyf @ glyfStart + realOffset;
    }
};

struct LocaTable {
    if (indexToLocFormat == 1) {
        //u32 offsets[gNumGlyphs + 1];
        GlyfWithOffset<true> glyfs[gNumGlyphs];
    } else {
        // u16 offsets[gNumGlyphs + 1];
        GlyfWithOffset<false> glyfs[gNumGlyphs];
    }
};

// end loca

// begin LTSH

struct LTSHTable {
    u16 version, numGlyphs;
    u8 yPixels[numGlyphs];
};

// end LTSH

// begin maxp

bitfield Version16Dot16 {
    major : 16;
    minor : 4;
    padding : 12;
};

struct MaxpTable {
    Version16Dot16 version;
    u16 numGlyphs;
    gNumGlyphs = numGlyphs;
    if (!hasPostScriptOutlines) {
        u16 maxPoints;
        u16 maxContours;
        u16 maxComponentPoints;
        u16 maxComponentContours;
        u16 maxZones;
        u16 maxTwilightPoints;
        u16 maxStorage;
        u16 maxFunctionDefs;
        u16 maxInstructionDefs;
        u16 maxStackElements;
        u16 maxSizeOfElements;
        u16 maxComponentDepth;
    }
};

// end maxp

// begin name

u64 curStorageOffset;

struct NameRecord {
    u16 platformId;
    u16 encodingId;
    u16 languageId;
    u16 nameId;
    u16 length;
    u16 stringOffset;
    char16 string[length / 2] @ curStorageOffset + stringOffset;
};

struct LangTagRecord {
    u16 length;
    u16 langTagOffset;
    char16 langTag[length / 2] @ curStorageOffset + langTagOffset;
};

struct NameTableV0 {
    u64 startOfNameTable = $;
    u16 version;
    u16 count;
    u16 storageOffset;
    curStorageOffset = startOfNameTable + storageOffset;
    NameRecord nameRecords[count];
};

struct NameTableV1 : NameTableV0 {
    u16 langTagCount;
    LangTagRecord langTagRecords[langTagCount];
};

struct NameTable {
    u16 version = std::mem::read_unsigned($, 2, std::mem::Endian::Big);

    match (version) {
        (0): NameTableV0 table [[inline]];
        (_): NameTableV1 table [[inline]];
    }
};

// end name

// begin OS/2

struct OS2TableV0 {
    u16 version;
    FWord xAvgCharWidth;
    u16 usWeightClass;
    u16 usWidthClass;
    u16 fsType;
    FWord ySubscriptXSize;
    FWord ySubscriptYSize;
    FWord SubscriptXOffset;
    FWord SubscriptYOffset;
    FWord ySuperscriptXSize;
    FWord ySuperscriptYSize;
    FWord SuperscriptXOffset;
    FWord SuperscriptYOffset;
    FWord yStrikeoutSize;
    FWord yStrikeoutPosition;
    s16 sFamilyClass;
    u8 panose[10];
    u32 ulUnicodeRange[4];
    u8 achVendID[4];
    u16 fsSelection;
    u16 usFirstCharIndex;
    u16 usLastCharIndex;
    FWord sTypoAscender;
    FWord sTypoDescender;
    FWord sTypoLineGap;
    UFWord usWinAscent;
    UFWord usWinDescent;
};

struct OS2TableV1 : OS2TableV0 {
    u32 ulCodePageRange[2];
};

struct OS2TableV4 : OS2TableV1 {
    FWord sxHeight;
    FWord sCapHeight;
    u16 usDefaultChar;
    u16 usBreakChar;
    u16 usMaxContent;
};

struct OS2TableV5 : OS2TableV4 {
    u16 usLowerOpticalPointSize;
    u16 usUpperOpticalPointSize;
};

struct OS2Table {
    u16 version = std::mem::read_unsigned($, 2, std::mem::Endian::Big);

    match (version) {
        (0): OS2TableV0 table [[inline]];
        (1): OS2TableV1 table [[inline]];
        (2 | 3 | 4): OS2TableV4 table [[inline]];
        (_): OS2TableV5 table [[inline]];
    }
};

// end OS/2

// begin PCLT

bitfield FontNumberFlag {
    converted : 1;
};

// yes this is set up as a janky union
// I can't think of any other way to read the flag *and* the vendor character
union FlagVendor {
    FontNumberFlag flag;
    char vendor;
};

struct FontNumber {
    FlagVendor flagVendor;
    u24 fontNumber;
};

enum Posture : u8 {
    Upright,
    Italic,
    AltItalic,
    Reserved
};

enum AppearanceWidth : u8 {
    Normal,
    Condensed,
    CompressedExtraCondensed,
    ExtraCompressed,
    UltraCompressed,
    Reserved,
    ExtendedExpanded,
    ExtraExtendedExpanded
};

enum Structure : u8 {
    Solid,
    Outline,
    Inline,
    ContourDistressed,
    SolidShadow,
    OutlineShadow,
    InlineShadow,
    ContourShadow,
    Patterned = 8 ... 11,
    PatternedShadow = 12 ... 15,
    Inverse,
    InverseOpenBorder,
    Reserved = 18 ... 30,
    Unknown
};

bitfield Style {
    Posture posture : 2;
    AppearanceWidth appearanceWidth : 3;
    Structure structure : 5;
    padding : 6;
};

enum TypeVendor : u8 {
    Reserved,
    Agfa,
    Bitstream,
    Linotype,
    Monotype,
    Adobe,
    FontRepackager,
    UniqueVendor,
    Reserved = 8 ... 15
};

bitfield TypeFamily {
    TypeVendor vendor : 4;
    familyNumber : 12;
};

enum StrokeWeight : s8 {
    UltraThin = -7,
    ExtraThin,
    Thin,
    ExtraLight,
    Light,
    Demilight,
    Semilight,
    Book,
    Semibold,
    Demibold,
    Bold,
    ExtraBold,
    Black,
    ExtraBlack,
    UltraBlack
};

enum WidthType : s8 {
    UltraCompressed = -5,
    ExtraCompressed,
    Compressed,
    Condensed,
    Normal = 0,
    Expanded = 2,
    ExtraExpanded
};

enum SerifStyleLower : u8 {
    SansSerifSquare,
    SansSerifRound,
    SerifLine,
    SerifTriangle,
    SerifSwath,
    SerifBlock,
    SerifBracket,
    RoundedBracket,
    FlairSerif,
    ScriptNonconnecting,
    ScriptJoining,
    ScriptCalligraphic,
    ScriptBrokenLetter,
    Reserved = 13 ... 63
};

enum SerifStyleUpper : u8 {
    Reserved,
    SansSerif,
    Serif,
    Reserved
};

bitfield SerifStyle {
    SerifStyleUpper ssUpper : 2;
    SerifStyleLower ssLower : 6;
};

struct PCLTTable {
    u16 majorVersion, minorVersion;
    FontNumber fontNumber;
    u16 pitch, xHeight;
    Style style;
    TypeFamily typeFamily;
    u16 capHeight, symbolSet;
    char typeface[16];
    s8 characterComplement[8];
    char fileName[6];
    StrokeWeight strokeWeight;
    WidthType widthType;
    SerifStyle serifStyle;
    padding[1];
};

// end PCLT

// begin post

struct PostTableV1 {
    u64 startOfTable = $;
    FixedPoint32 version;
    FixedPoint32 italicAngle;
    FWord underlinePosition;
    FWord underlineThickness;
    u32 isFixedPitch;
    u32 minMemType42;
    u32 maxMemType42;
    u32 minMemType1;
    u32 maxMemType1;
};

struct PostTableV2 : PostTableV1 {
    u16 numGlyphs;
    u16 glyphNameIndex[numGlyphs];
    std::string::SizedString<u8> stringData[while ($ < startOfTable + currentLength)];
};

struct PostTable {
    u16 major = std::mem::read_unsigned($, 2, std::mem::Endian::Big);
    u16 minor = std::mem::read_unsigned($ + 2, 2, std::mem::Endian::Big);

    match (major, minor) {
        (2, 0): PostTableV2 table [[inline]];
        (_, _): PostTableV1 table [[inline]];
    }
};

// end post

// start STAT



struct STATTable {
    u16 majorVersion, minorVersion, designAxisSize, designAxisCount;
    u32 designAxesOffset;
    u16 axisValueCount;
    u32 offsetToAxisValueOffsets;
    u16 elidedFallbackNameID;
};

// end STAT

// start SVG

struct SVGDocumentRecord {
    u16 startGlyphID, endGlyphID;
    u32 svgDocOffset, svgDocLength;
    u8 svgDoc[svgDocLength] @ parent.startOfSVGDocumentList + svgDocOffset;
};

struct SVGDocumentList {
    u64 startOfSVGDocumentList = $;
    u16 numEntries;
    SVGDocumentRecord documentRecords[numEntries];
};

struct SVGTable {
    u64 startOfSVGTable = $;
    u16 version;
    u32 svgDocumentListOffset;
    u32 reserved;
    SVGDocumentList subtable @ startOfSVGTable + svgDocumentListOffset;
    
};

// end SVG

// start VDMX

struct RatioRange {
    u8 bCharSet, xRatio, yStartRatio, yEndRatio;
};

struct vTable {
    u16 yPelHeight;
    s16 yMax, yMin;
};

struct VDMXGroup {
    u16 recs;
    u8 startsz, endsz;
    vTable entry[recs];
};

struct VDMXGroupOffset {
    u16 groupOffset;
    VDMXGroup group @ parent.startOfVDMX + groupOffset;
};

struct VDMXTable {
    u64 startOfVDMX = $;
    u16 version, numRecs, numRatios;
    RatioRange ratRange[numRatios];
    VDMXGroupOffset vdmxGroupOffsets[numRatios];
};

// end VDMX

// start vhea

struct VheaTable {
    Version16Dot16 version;
    FWord ascent, descent, lineGap;
    UFWord advanceHeightMax;
    FWord minTopSideBearing, minBottomSideBearing, yMaxExtent;
    s16 caretSlopeRise, caretSlopeRun, caretOffset;
    padding[8];
    s16 metricDataFormat;
    u16 numOfLongVerMetrics;
};

// end vhea

// start vmtx

struct VerticalMetrics {
    UFWord advanceHeight;
    FWord topSideBearing;
};

struct VmtxTable {
    VerticalMetrics verticalMetrics[numOfLongVerMetrics];
    FWord monospaceTopSideBearing[gNumGlyphs - numOfLongVerMetrics];
};

// end vmtx

struct HiddenForPreprocessing {
    u64 defStart = $;
    TableDirectory td;
    $ = td.offset;
    currentOffset = td.offset;
    currentLength = td.length;
    match (td.tag) {
        ("CFF "): {
            hasPostScriptOutlines = true;
        }
        ("maxp"): MaxpTable table;
        ("head"): {
            HeadTable table;
            indexToLocFormat = table.indexToLocFormat;
        }
        ("vhea"): {
            VheaTable table;
            numOfLongVerMetrics = table.numOfLongVerMetrics;
        }
        ("glyf"): {
            glyfStart = $;
        }
    }
    $ = defStart + sizeof(TableDirectory);
} [[hidden]];

struct Table {
    u64 defStart = $;
    TableDirectory td [[inline]];
    $ = td.offset;
    currentOffset = td.offset;
    currentLength = td.length;
    match (td.tag) {
        ("avar"): AvarTable table;
        ("bhed"): HeadTable table;
        ("cmap"): CmapTable table;
        ("COLR"): ColrTable table;
        ("CPAL"): CpalTable table;
        ("cvt "): CvtTable table;
        ("DSIG"): DSIGTable table;
        ("FFTM"): FFTMTable table;
        ("gasp"): GaspTable table;
        ("GDEF"): GDEFTable table;
        // ("glyf"): GlyfTable table;
        // glyf will be contained in loca.
        ("glyf"): {}
        ("hdmx"): HdmxTable table;
        ("head"): HeadTable table;
        ("hhea"): HheaTable table;
        ("hmtx"): HmtxTable table;
        ("loca"): LocaTable table;
        ("LTSH"): LTSHTable table;
        ("maxp"): MaxpTable table;
        ("name"): NameTable table;
        ("OS/2"): OS2Table table;
        ("PCLT"): PCLTTable table;
        ("post"): PostTable table;
        ("STAT"): STATTable table;
        ("SVG "): SVGTable table;
        ("VDMX"): VDMXTable table;
        ("vhea"): VheaTable table;
        ("vmtx"): VmtxTable table;
        (_): u8 data[td.length];
    }
    $ = defStart + sizeof(TableDirectory);
} [[name(std::format("Table({})", td.tag))]];


struct TTF {
    u32 scalarType;
    u16 numTables;
    u16 searchRange;
    u16 entrySelector;
    u16 rangeShift;

    HiddenForPreprocessing hidden[numTables] @ $ [[hidden]];

    Table tables[numTables];
};

TTF ttf @ 0x0;
