//
//  FontAtlas.swift
//  tether
//
//  Created by Zack Radisic on 07/06/2023.
//

import Foundation
import AppKit
import simd

struct GlyphInfo {
    let glyph: CGGlyph
    let rect: CGRect
    let tx: Float
    let ty: Float
    let advance: Float
    
    init() {
        self.init(glyph: CGGlyph(), rect: CGRect(), tx: 0.0, ty: 0.0)
    }
    init (glyph: CGGlyph, rect: CGRect) {
        self.init(glyph: glyph, rect: rect, tx: 0.0, ty: 0.0)
    }
    init (glyph: CGGlyph, rect: CGRect, tx: Float, ty: Float) {
        self.init(glyph: glyph, rect: rect, tx: ty, ty: tx, advance: 0.0)
    }
    init (glyph: CGGlyph, rect: CGRect, tx: Float, ty: Float, advance: Float) {
        self.glyph = glyph
        self.rect = rect
        self.tx = tx
        self.ty = ty
        self.advance = advance
    }
    
    func texCoords() -> [float2] {
        //        let left = Float(0.0)
        //        let right = Float(1.0)
        //        let top = Float(1.0)
        //        let bot = Float(0.0)
        
        let left = Float(self.rect.minX)
        let right = Float(self.rect.maxX)
        let top = Float(self.rect.origin.y + self.rect.height)
        let bot = Float(self.rect.origin.y )
        
        //        let left = Float(526.0 / 1024)
        //        let right = Float(538.0 / 1024)
        //        let top = Float(35 / 58)
        //        let bot = Float(54 / 58)
        //        let bot = Float(35.0 / 58.0)
        //        let top = Float(54.0 / 58.0)
        
        return [
            float2(left, top),
            float2(left, bot),
            float2(right, bot),
            
            float2(right, bot),
            float2(right, top),
            float2(left, top),
        ]
    }
    
    //    func texCoords() -> [float2] {
    //        let left = Float(self.rect.origin.x)
    //        let right = left + Float(self.rect.width)
    //        let top = Float(self.rect.origin.y)
    //        let bot = top + Float(self.rect.height)
    //
    //        return [
    //            float2(left, bot),
    //            float2(left, top),
    //            float2(right, top),
    //
    //            float2(right, top),
    //            float2(right, bot),
    //            float2(left, bot),
    //        ]
    //    }
    
    //    func texCoords() -> [float2] {
    //        return [
    //            float2(0, 1),
    //            float2(0, 0),
    //            float2(1, 0),
    //
    //            float2(1, 0),
    //            float2(1, 1),
    //            float2(0, 1),
    //        ]
    //    }
    
}

/// Only supports monospaced fonts right now
class FontAtlas {
    //    var characters = String("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
//    var font = NSFont.systemFont(ofSize: 48) // Or any other font you want
        var font: NSFont = NSFont(name: "Iosevka SS04", size: 48)!
    let margin: CGFloat = 4
    let MAX_WIDTH = 1024.0
    var max_glyph_height: Float = 0.0
    var max_glyph_height_normalized: Float = 0.0
    var glyph_info: [GlyphInfo] = []
    var atlas: CGImage!
    
    func lookupChar(char: UInt8) -> GlyphInfo {
        assert(char < glyph_info.count)
        return self.glyph_info[Int(char)]
    }
    
    func makeAtlas() {
        let CHAR_END: UInt8 = 127;
        self.glyph_info = [GlyphInfo](repeating: GlyphInfo(), count: Int(CHAR_END));
        
        var cchars: [UInt8] = (32..<CHAR_END).map { i in i }
        cchars.append(0)
        let characters = String(cString: cchars)
        
        /// Calculate glyphs for our characters
        var unichars = [UniChar](repeating: 0, count: CFStringGetLength(characters as NSString))
        (characters as NSString).getCharacters(&unichars)
        
        var glyphs = [CGGlyph](repeating: 0, count: unichars.count)
        let gotGlyphs = CTFontGetGlyphsForCharacters(font, unichars, &glyphs, unichars.count)
        if !gotGlyphs {
            fatalError("Well we fucked up.")
        }
        
        var glyph_rects = [CGRect](repeating: CGRect(), count: glyphs.count);
        let total_bounding_rect = CTFontGetBoundingRectsForGlyphs(font, .horizontal, &glyphs, &glyph_rects, glyphs.count)
        
        var roww = 0.0
        var rowh = 0.0
        var w = 0.0
        var h = 0.0
        var max_w = 0.0
        for i in 32..<CHAR_END {
            let j = Int(i - 32);
            let glyph = glyphs[j];
            let glyph_rect = glyph_rects[j];
            
            if roww + glyph_rect.width + 1.0 >= MAX_WIDTH {
                w = max(w, roww);
                h += rowh
                roww = 0
                rowh = 0
            }
            
            max_w = max(max_w, glyph_rect.width)
            
            roww += glyph_rect.width + 1
            rowh = max(rowh, glyph_rect.height)
        }
        
        let max_h = rowh;
        w = max(w, roww);
        h += rowh;
        
        let tex_w = Int(ceil(w))
        let tex_h = Int(ceil(h))
        
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: tex_w, height: tex_h, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.0, green: 0, blue: 0, alpha: 0.0))
        context.fill(CGRect(x: 0, y: 0, width: tex_w, height: tex_h))
        let ctfont = CTFontCopyGraphicsFont(font, nil)
        context.setFont(ctfont)
        context.setFontSize(48)
        

        context.setFillColor(CGColor(red: 0.0, green: 1, blue: 0, alpha: 1.0))
        var ox: Int = 0
        var oy: Int = 0
        var rowhh: Int = 0
        
        for i in 32..<CHAR_END {
            let j = Int(i - 32);
            let glyph = glyphs[j];
            let rect = glyph_rects[j];
            
            let rectw = Int(ceil(rect.width))
            let recth = Int(ceil(rect.height))
            
            if ox + rectw + 1 >= Int(MAX_WIDTH) {
                ox = 0;
                oy += rowhh;
                rowh = 0
            }
            
            
            let tx = Float(ox) / Float(tex_w)
            let ty = Float(oy) / Float(tex_h)
            let oy_cg = Float(tex_h - oy)
            var the_glyph: [CGGlyph] = [glyph]
            context.showGlyphs([glyph], at: [CGPoint(x: Double(ox), y: Double(oy_cg))])
            
            var advances: [Int32] = [0]
            ctfont.getGlyphAdvances(glyphs: &the_glyph, count: 1, advances: &advances)
            
            self.glyph_info[j] = GlyphInfo(
                glyph: glyph,
                rect: rect,
                tx: tx,
                ty: ty,
                advance: Float(advances[0])
            )
            
            rowhh = max(rowhh, recth)
            ox += rectw + 1
        }
        
        atlas = context.makeImage()!
    }
    
    //    func makeAtlas() {
    //        var atlas_height: Int
    //        let atlas_width: Int = Int(MAX_WIDTH);
    //
    //        var cchars: [UInt8] = (32...126).map{ i in i }
    //        cchars.append(0)
    //        let characters = String(cString: cchars)
    //
    //        /// Calculate glyphs for our characters
    //        var unichars = [UniChar](repeating: 0, count: CFStringGetLength(characters as NSString))
    //        (characters as NSString).getCharacters(&unichars)
    //        var glyphs = [CGGlyph](repeating: 0, count: unichars.count)
    //
    //        let gotGlyphs = CTFontGetGlyphsForCharacters(font, unichars, &glyphs, unichars.count)
    //        if !gotGlyphs {
    //            fatalError("Well we fucked up.")
    //        }
    //
    //        /// Set glyph rects and atlwas w/h
    //        var glyph_rects = [CGRect](repeating: CGRect(), count: glyphs.count);
    //        let total_bounding_rect = CTFontGetBoundingRectsForGlyphs(font, .horizontal, &glyphs, &glyph_rects, glyphs.count)
    //        let max_glyph_height = total_bounding_rect.height;
    //        print("ALL GLYPHS BEFORE HAND \(glyph_rects.map{ rect in rect.origin })")
    //        print("OVERALL \(total_bounding_rect)")
    //        self.max_glyph_height = Float(max_glyph_height)
    //
    //        var x: CGFloat = margin
    //        var y: CGFloat = margin
    //        for (i, glyph_rect) in glyph_rects.enumerated() {
    //            if x + glyph_rect.width >= MAX_WIDTH - margin {
    //                y += max_glyph_height + margin;
    //                x = margin;
    //            }
    //            glyph_rects[i] = CGRect(x: x, y: y, width: glyph_rect.width, height: glyph_rect.height);
    //            x += glyph_rect.width + margin
    //        }
    //        atlas_height = Int(ceil(y + max_glyph_height + margin));
    //        self.max_glyph_height_normalized = self.max_glyph_height / Float(atlas_height)
    //
    //        /// Create a context for drawing
    //        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    //        let context = CGContext(data: nil, width: Int(atlas_width), height: Int(atlas_height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    //
    //        context.setFillColor(CGColor(red: 0.0, green: 0, blue: 0, alpha: 0.0))
    //        context.fill(CGRect(x: 0, y: 0, width: atlas_width, height: atlas_height))
    //
    //        context.setFont(CTFontCopyGraphicsFont(font, nil))
    //        context.setFontSize(24)
    //
    //        //        context.setFillColor(CGColor.white)
    //        context.setFillColor(CGColor(red: 1.0, green: 1, blue: 1, alpha: 1))
    //
    //        /// Draw all the glyphs line by line
    //        var glyph_pos = glyph_rects.map { rect in
    //            CGPoint(x: rect.origin.x, y: rect.origin.y)
    //        };
    //        var rowStart = 0;
    //        var rowEnd = 0;
    //        while rowStart < glyph_rects.count {
    //            let current_y = glyph_rects[rowStart].minY;
    //
    //            rowEnd = rowStart + 1;
    //            for (i, glyph) in glyph_rects[rowStart...].enumerated() {
    //                if glyph.minY != current_y {
    //                    rowEnd = rowStart + i;
    //                }
    //            }
    //
    //            let count = rowEnd - rowStart;
    //            ShowGlyphsAtPositions(context, &glyphs, &glyph_pos, rowStart, count);
    //            rowStart = rowEnd;
    //        }
    //
    //        // Now you can use the context to create a CGImage
    //        atlas = context.makeImage()!
    //
    //        let url = URL(fileURLWithPath: "/Users/zackradisic/Code/tether/atlas.png")
    //        let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil)
    //        CGImageDestinationAddImage(destination!, atlas, nil)
    //        CGImageDestinationFinalize(destination!)
    //
    ////        let fGlyph = glyph_rects[70 - 32]
    ////        print("THE GLYPH x=\(fGlyph.origin.x) y=\(fGlyph.origin.y) w=\(fGlyph.width) h\(fGlyph.height)")
    ////        //        let rect = CGRect(x: fGlyph.origin.x, y:  fGlyph.origin.y, width: 200, height: 200)
    ////        let rect = CGRect(x: fGlyph.origin.x, y:  CGFloat(atlas_height) - fGlyph.origin.y - fGlyph.height, width: fGlyph.width, height: fGlyph.height)
    ////        let newImage = atlas.cropping(to: rect)!
    ////        let myUrl = URL(fileURLWithPath: "/Users/zackradisic/Code/tether/atlas-test2.png")
    ////        let mydestination = CGImageDestinationCreateWithURL(myUrl as CFURL, kUTTypePNG, 1, nil)
    ////        CGImageDestinationAddImage(mydestination!, newImage, nil)
    ////        CGImageDestinationFinalize(mydestination!)
    //
    //
    //
    //        self.glyphs = [GlyphInfo](repeating: GlyphInfo(glyph: CGGlyph(), rect: CGRect()), count: glyphs.count)
    //        for (i, glyph) in glyphs.enumerated() {
    //            var rect = glyph_rects[i]
    //            //            let new_y = CGFloat(atlas_height) - rect.origin.y - rect.height;
    //            let new_y = CGFloat(atlas_height) - rect.origin.y - rect.height;
    //            self.glyphs[i] = GlyphInfo(glyph: glyph, rect: CGRect(x: rect.origin.x / CGFloat(atlas_width), y: new_y / CGFloat(atlas_height), width: (rect.width / CGFloat(atlas_width)), height: (rect.height / CGFloat(atlas_height))))
    //        }
    //
    //        let fGlyph = self.glyphs[70 - 32].rect
    //        print("THE GLYPH x=\(fGlyph.origin.x) y=\(fGlyph.origin.y) w=\(fGlyph.width) h\(fGlyph.height)")
    //        let rect = CGRect(x: fGlyph.origin.x, y: fGlyph.origin.y, width: fGlyph.width, height: fGlyph.height)
    //        let newImage = atlas.cropping(to: rect)!
    //        let myUrl = URL(fileURLWithPath: "/Users/zackradisic/Code/tether/atlas-test2.png")
    //        let mydestination = CGImageDestinationCreateWithURL(myUrl as CFURL, kUTTypePNG, 1, nil)
    //        CGImageDestinationAddImage(mydestination!, newImage, nil)
    //        CGImageDestinationFinalize(mydestination!)
    //
    //    }
}
