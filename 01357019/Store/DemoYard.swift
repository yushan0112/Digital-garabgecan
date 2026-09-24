import Foundation

/// The bundled demo yard.
///
/// This is not a placeholder — it is a shipping requirement. The classroom demo may run
/// on a simulator with no photos, no granted permissions and no Apple Intelligence, and
/// the whole loop still has to be playable. Items are hand-tuned so the yard opens at a
/// high junk load with every pile and every score factor represented.
enum DemoYard {

    static func seed() -> [JunkItem] {
        var items: [JunkItem] = []
        var swatch = 0

        func add(
            _ name: String,
            _ kind: JunkKind,
            mb: Double?,
            daysAgo: Int?,
            twin: String? = nil,
            purpose: String? = nil
        ) {
            let created = daysAgo.map { Calendar.current.date(byAdding: .day, value: -$0, to: .now) ?? .now }
            items.append(JunkItem(
                name: name,
                kind: kind,
                byteSize: mb.map { Int64($0 * 1_048_576) },
                createdAt: created,
                twinGroup: twin,
                purposeTag: purpose,
                swatch: swatch,
                // Stagger discovery times so "最近發現" has a meaningful order.
                discoveredAt: Calendar.current.date(byAdding: .minute, value: -swatch * 7, to: .now) ?? .now
            ))
            swatch += 1
        }

        // 截圖山 — the biggest pile, mostly system-named and long forgotten.
        add("IMG_4821.PNG", .screenshot, mb: 2.4, daysAgo: 412)
        add("Screenshot 2024-11-02 at 14.32.11.png", .screenshot, mb: 3.1, daysAgo: 326)
        add("IMG_4822.PNG", .screenshot, mb: 2.2, daysAgo: 412)
        add("螢幕快照 2025-01-08 下午3.14.png", .screenshot, mb: 1.8, daysAgo: 259)
        add("IMG_5533.PNG", .screenshot, mb: 2.9, daysAgo: 198)
        add("Screenshot 2025-04-17 at 09.02.44.png", .screenshot, mb: 3.6, daysAgo: 160)
        add("IMG_6120.PNG", .screenshot, mb: 2.1, daysAgo: 96)
        add("螢幕擷取畫面-2025-06-30.png", .screenshot, mb: 2.7, daysAgo: 86)
        add("IMG_6688.PNG", .screenshot, mb: 1.4, daysAgo: 41)
        add("meme_存起來以後用.png", .screenshot, mb: 1.1, daysAgo: 22)
        add("Screenshot 2025-09-01 at 23.58.02.png", .screenshot, mb: 4.2, daysAgo: 23)
        add("IMG_7001.PNG", .screenshot, mb: 2.3, daysAgo: 9)
        add("receipt_蝦皮_訂單.png", .screenshot, mb: 0.9, daysAgo: 54)
        add("IMG_3390.PNG", .screenshot, mb: 2.6, daysAgo: 620)
        add("IMG_3391.PNG", .screenshot, mb: 2.5, daysAgo: 619)
        add("IMG_3392.PNG", .screenshot, mb: 2.8, daysAgo: 615)
        add("Screenshot 2024-02-11 at 01.19.53.png", .screenshot, mb: 3.4, daysAgo: 591)
        add("螢幕快照 2024-03-02 上午1.07.png", .screenshot, mb: 2.2, daysAgo: 571)
        add("IMG_4102.PNG", .screenshot, mb: 1.9, daysAgo: 503)
        add("IMG_4419.PNG", .screenshot, mb: 2.7, daysAgo: 466)
        add("螢幕擷取畫面-2024-07-19.png", .screenshot, mb: 3.0, daysAgo: 432)
        add("IMG_5001.PNG", .screenshot, mb: 2.4, daysAgo: 388)
        add("Screenshot 2024-10-05 at 16.41.29.png", .screenshot, mb: 3.3, daysAgo: 354)
        add("IMG_5210.PNG", .screenshot, mb: 2.0, daysAgo: 341)

        // 雙胞胎堆 — three twin groups, each with a defensible "keep this one".
        add("CS101_final_report.pdf", .document, mb: 4.8, daysAgo: 210, twin: "twin-A")
        add("CS101_final_report (1).pdf", .document, mb: 4.8, daysAgo: 209, twin: "twin-A")
        add("IMG_2201.HEIC", .photo, mb: 3.4, daysAgo: 488, twin: "twin-B")
        add("IMG_2202.HEIC", .photo, mb: 3.9, daysAgo: 488, twin: "twin-B")
        add("IMG_2203.HEIC", .photo, mb: 3.2, daysAgo: 488, twin: "twin-B")
        add("報告_最終版.docx", .document, mb: 1.6, daysAgo: 133, twin: "twin-C")
        add("報告_最終版_真的最終.docx", .document, mb: 1.7, daysAgo: 131, twin: "twin-C")
        add("報告_最終版(2).docx", .document, mb: 1.6, daysAgo: 130, twin: "twin-C")
        add("IMG_6402.PNG", .screenshot, mb: 2.6, daysAgo: 372, twin: "twin-D")
        add("IMG_6403.PNG", .screenshot, mb: 2.6, daysAgo: 372, twin: "twin-D")
        add("課表_下學期.png", .screenshot, mb: 1.4, daysAgo: 240, twin: "twin-E")
        add("課表_下學期(1).png", .screenshot, mb: 1.4, daysAgo: 240, twin: "twin-E")

        // 巨獸區 — the heavyweights.
        add("IMG_0912.MOV", .photo, mb: 782, daysAgo: 540)
        add("lecture_recording_week07.m4a", .download, mb: 224, daysAgo: 300)
        add("畢業旅行_未剪.mp4", .photo, mb: 1340, daysAgo: 430, purpose: "回憶備份")
        add("IMG_1180.MOV", .photo, mb: 610, daysAgo: 275)
        add("Xcode_beta.xip", .download, mb: 8900, daysAgo: 88)

        // 遺跡區 — old but reasonably named documents.
        add("microeconomics_week03_notes.pdf", .document, mb: 2.2, daysAgo: 690)
        add("線性代數_期中考古題.pdf", .document, mb: 5.4, daysAgo: 640, purpose: "課堂資料")
        add("statistics_lab04.pdf", .document, mb: 1.9, daysAgo: 520)
        add("台北租屋合約_2023.pdf", .document, mb: 3.3, daysAgo: 610, purpose: "重要文件")
        add("演算法_homework06.pdf", .document, mb: 1.1, daysAgo: 470)
        add("生涯規劃_resume_v3.pdf", .document, mb: 0.8, daysAgo: 380)

        // 無名氏 — no date at all, which is exactly the "資料不足" case the UI must handle.
        add("未命名.pdf", .download, mb: 1.3, daysAgo: nil)
        add("document(3).pdf", .download, mb: 2.8, daysAgo: nil)
        add("download.tmp", .unknown, mb: nil, daysAgo: nil)
        add("2025-07-14 21.44.10", .unknown, mb: 0.6, daysAgo: 71)
        add("scan_0001.jpg", .download, mb: 1.7, daysAgo: 155)
        add("IMG_9034.HEIC", .photo, mb: 2.9, daysAgo: 350)

        // A few genuinely tidy items, so "可回收" is not a theoretical level.
        add("行動支付_發票_20250902.pdf", .document, mb: 0.4, daysAgo: 22, purpose: "收據與帳單")
        add("宿舍水電費_09月.pdf", .document, mb: 0.3, daysAgo: 14)
        add("社團活動企劃書_v2.docx", .document, mb: 1.2, daysAgo: 30)
        add("ios課程_期末專題_規劃.pdf", .document, mb: 2.6, daysAgo: 5, purpose: "課堂資料")

        return items
    }
}
