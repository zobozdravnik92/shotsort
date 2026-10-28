#if DEBUG
import UIKit

/// Realistic fake screenshots for testing in the Simulator, drawn in code so no image files ship.
/// They are saved into the debug samples folder and go through the normal pipeline.
@MainActor
enum MockScreenshots {
    enum Block {
        case title(String)
        case subtitle(String)
        case body(String)
        case meta(String)
        case price(String)
        case button(String)
        case bubble(String, mine: Bool)
        case gap
    }

    struct Mock {
        let name: String
        let app: String
        let accent: UIColor
        let daysAgo: Int
        let blocks: [Block]
    }

    private static let linkedIn = UIColor(red: 0.04, green: 0.40, blue: 0.76, alpha: 1)
    private static let x = UIColor.black
    private static let shop = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
    private static let green = UIColor(red: 0.13, green: 0.62, blue: 0.36, alpha: 1)
    private static let purple = UIColor(red: 0.42, green: 0.32, blue: 0.86, alpha: 1)

    static let all: [Mock] = [
        // Jobs
        Mock(name: "job-acme", app: "LinkedIn", accent: linkedIn, daysAgo: 2, blocks: [
            .title("Senior Product Designer"),
            .subtitle("Acme Pay · Berlin, Germany (Hybrid)"),
            .meta("€85,000 – €100,000 / year · Full-time · Senior level"),
            .gap,
            .body("About the job"),
            .body("We're hiring a senior designer to lead our design system and payments flows."),
            .body("Requirements: 5+ years of experience, Figma, prototyping, working with engineers."),
            .button("Easy Apply"),
        ]),
        Mock(name: "job-northwind", app: "LinkedIn", accent: linkedIn, daysAgo: 6, blocks: [
            .title("Staff Designer, Growth"),
            .subtitle("Northwind · Remote (Europe)"),
            .meta("Full-time · Staff · Posted 3 days ago"),
            .gap,
            .body("Own onboarding and activation experiments across web and mobile."),
            .body("Responsibilities: run experiments, partner with PMs, mentor designers."),
            .body("Qualifications: 8+ years of experience in product design."),
            .button("Apply"),
        ]),
        Mock(name: "job-lumen", app: "Indeed", accent: purple, daysAgo: 35, blocks: [
            .title("Product Designer"),
            .subtitle("Lumen Labs · Ljubljana (On-site)"),
            .meta("€48,000 – €58,000 a year · Full-time · Mid level"),
            .gap,
            .body("Join a small team building tools for clinics."),
            .body("Requirements: 3+ years of experience, strong UI craft."),
            .button("Apply now"),
        ]),
        // Posts and ideas
        Mock(name: "post-portfolio", app: "LinkedIn", accent: linkedIn, daysAgo: 1, blocks: [
            .subtitle("Jamie Rivera · 2nd"),
            .meta("Design lead at Figma · 1d"),
            .gap,
            .body("Portfolio reviews should start with the problem, not the pixels."),
            .body("Lead with your role, the constraint, and the outcome. Then show screens."),
            .meta("…more"),
            .gap,
            .meta("1,204 likes · 87 comments · 32 reposts"),
        ]),
        Mock(name: "post-thread", app: "X", accent: x, daysAgo: 9, blocks: [
            .subtitle("Sara Lin @saralin"),
            .gap,
            .body("A thread on naming design tokens 🧵"),
            .body("1/ Name tokens by purpose, not by value. \"text-muted\" survives a rebrand, \"gray-500\" doesn't."),
            .body("2/ Keep three tiers: primitives, semantic, component."),
            .gap,
            .meta("214 replies · 1.1K reposts · 6.4K likes"),
        ]),
        // People
        Mock(name: "person-priya", app: "LinkedIn", accent: linkedIn, daysAgo: 4, blocks: [
            .title("Priya Shah"),
            .subtitle("Design Manager at Ledgerly"),
            .meta("London, United Kingdom · 500+ connections"),
            .gap,
            .body("Hiring product designers for our fintech team. Open to coffee chats."),
            .meta("12 mutual connections"),
            .button("Connect"),
        ]),
        Mock(name: "person-marko", app: "LinkedIn", accent: linkedIn, daysAgo: 20, blocks: [
            .title("Marko Novak"),
            .subtitle("Founder & CEO at Tidepool"),
            .meta("Ljubljana, Slovenia · 2,300 followers"),
            .gap,
            .body("Building calm software for small teams. Previously design at Outfit7."),
            .button("Message"),
        ]),
        // Inspiration
        Mock(name: "insp-paywall", app: "Headway", accent: green, daysAgo: 12, blocks: [
            .title("Unlock everything"),
            .body("Read 1,500+ book summaries"),
            .body("Listen offline"),
            .body("Personal reading plan"),
            .gap,
            .price("€6.99 per month"),
            .meta("7-day free trial, cancel anytime"),
            .button("Start free trial"),
        ]),
        Mock(name: "insp-onboarding", app: "Calm", accent: purple, daysAgo: 15, blocks: [
            .title("What brings you here?"),
            .body("Sleep better"),
            .body("Reduce stress"),
            .body("Build a daily habit"),
            .gap,
            .button("Continue"),
            .meta("Already have an account? Log in"),
        ]),
        // Shopping
        Mock(name: "shop-jumper", app: "ARKET", accent: shop, daysAgo: 3, blocks: [
            .title("Merino crew neck jumper"),
            .price("€89"),
            .meta("Navy · Size M · In stock"),
            .body("Free delivery over €50"),
            .button("Add to bag"),
            .meta("Reviews (214)"),
        ]),
        Mock(name: "shop-headphones", app: "Amazon", accent: UIColor(red: 0.14, green: 0.18, blue: 0.24, alpha: 1), daysAgo: 8, blocks: [
            .title("Sony WH-1000XM6 Wireless Headphones"),
            .price("€379.00"),
            .meta("In stock · Free delivery Friday"),
            .body("Sold by Amazon EU"),
            .button("Add to cart"),
            .button("Buy now"),
        ]),
        // Receipts and docs
        Mock(name: "receipt-train", app: "Wallet", accent: UIColor.darkGray, daysAgo: 5, blocks: [
            .title("Receipt"),
            .subtitle("Slovenske železnice"),
            .body("Ljubljana → Zagreb, 14 Nov"),
            .body("Subtotal €17.90"),
            .body("VAT €1.50"),
            .price("Total €19.40"),
            .meta("Paid with Apple Pay · Order number 48213"),
        ]),
        Mock(name: "receipt-ride", app: "Bolt", accent: green, daysAgo: 11, blocks: [
            .title("Thanks for riding"),
            .subtitle("Trip to Ljubljana Airport"),
            .body("Ride fare €21.60"),
            .body("Service fee €1.20"),
            .price("Total €22.80"),
            .meta("Paid with Visa •••• 4242 · Receipt #BX-77120"),
        ]),
        // Conversations
        Mock(name: "chat-maja", app: "Messages", accent: UIColor.systemGray, daysAgo: 1, blocks: [
            .subtitle("Maja"),
            .meta("iMessage · Today 18:42"),
            .gap,
            .bubble("Are we still on for Friday dinner?", mine: false),
            .bubble("Yes! 7pm at Gostilna?", mine: true),
            .bubble("Perfect, see you there", mine: false),
            .meta("Delivered"),
        ]),
        // Other
        Mock(name: "other-weather", app: "Weather", accent: UIColor.systemTeal, daysAgo: 25, blocks: [
            .title("Ljubljana"),
            .price("14°"),
            .body("Partly cloudy"),
            .meta("H: 17° L: 8°"),
        ]),
    ]

    /// Names of mocks that are drawn twice, to test duplicate merging.
    static let duplicated = ["job-acme"]

    private static let size = CGSize(width: 1206, height: 2622)

    /// Writes any missing mocks into the samples folder. Returns how many were added.
    static func write() throws -> Int {
        let folder = SampleSource.folder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var added = 0
        for mock in all {
            var names = [mock.name]
            if duplicated.contains(mock.name) { names.append(mock.name + "-copy") }
            guard let data = render(mock).pngData() else { continue }
            for name in names {
                let url = folder.appending(path: "mock-\(name).png")
                guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { continue }
                try data.write(to: url)
                // Spread creation dates so sorting and "newest first" look realistic.
                let date = Date.now.addingTimeInterval(-Double(mock.daysAgo) * 86_400)
                try FileManager.default.setAttributes([.creationDate: date, .modificationDate: date], ofItemAtPath: url.path(percentEncoded: false))
                added += 1
            }
        }
        return added
    }

    static func render(_ mock: Mock) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            draw("9:41", font: .systemFont(ofSize: 50, weight: .semibold), color: .black, in: CGRect(x: 90, y: 60, width: 300, height: 70))

            // App header bar.
            mock.accent.setFill()
            context.fill(CGRect(x: 0, y: 170, width: size.width, height: 170))
            draw(mock.app, font: .systemFont(ofSize: 58, weight: .bold), color: .white, in: CGRect(x: 72, y: 215, width: size.width - 144, height: 90))

            var y: CGFloat = 420
            let width = size.width - 144
            for block in mock.blocks {
                switch block {
                case .title(let text):
                    y += draw(text, font: .systemFont(ofSize: 72, weight: .bold), color: .black, in: CGRect(x: 72, y: y, width: width, height: 400)) + 28
                case .subtitle(let text):
                    y += draw(text, font: .systemFont(ofSize: 52, weight: .semibold), color: .darkGray, in: CGRect(x: 72, y: y, width: width, height: 300)) + 22
                case .body(let text):
                    y += draw(text, font: .systemFont(ofSize: 48), color: .black, in: CGRect(x: 72, y: y, width: width, height: 400)) + 26
                case .meta(let text):
                    y += draw(text, font: .systemFont(ofSize: 40), color: .gray, in: CGRect(x: 72, y: y, width: width, height: 300)) + 22
                case .price(let text):
                    y += draw(text, font: .systemFont(ofSize: 66, weight: .heavy), color: .black, in: CGRect(x: 72, y: y, width: width, height: 200)) + 26
                case .button(let text):
                    let rect = CGRect(x: 72, y: y + 10, width: width, height: 130)
                    mock.accent.setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 65).fill()
                    let height = textHeight(text, font: .systemFont(ofSize: 50, weight: .semibold), width: width)
                    draw(text, font: .systemFont(ofSize: 50, weight: .semibold), color: .white, in: rect.insetBy(dx: 0, dy: (rect.height - height) / 2), centered: true)
                    y += rect.height + 40
                case .bubble(let text, let mine):
                    let font = UIFont.systemFont(ofSize: 48)
                    let maxWidth = width * 0.72
                    let textWidth = min(maxWidth, (text as NSString).size(withAttributes: [.font: font]).width + 2)
                    let height = textHeight(text, font: font, width: textWidth)
                    let bubble = CGRect(x: mine ? size.width - 72 - textWidth - 64 : 72, y: y, width: textWidth + 64, height: height + 44)
                    (mine ? UIColor.systemBlue : UIColor(white: 0.91, alpha: 1)).setFill()
                    UIBezierPath(roundedRect: bubble, cornerRadius: 44).fill()
                    draw(text, font: font, color: mine ? .white : .black, in: bubble.insetBy(dx: 32, dy: 22))
                    y += bubble.height + 24
                case .gap:
                    y += 40
                }
            }
        }
    }

    @discardableResult
    private static func draw(_ text: String, font: UIFont, color: UIColor, in rect: CGRect, centered: Bool = false) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = centered ? .center : .left
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        let string = NSAttributedString(string: text, attributes: attributes)
        let bounds = string.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        string.draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(bounds.height)), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return ceil(bounds.height)
    }

    private static func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        ceil((text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height)
    }
}
#endif
