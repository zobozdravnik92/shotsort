import Foundation
import Testing
@testable import ScreenshotSorter

struct CloudParsingTests {
    private let replyJSON = """
    {"category":"jobs","title":"Product Designer at yet to be","summary":"Hiring a product designer.",
     "fields":[{"key":"company","value":"yet to be"},{"key":"remote","value":"yes"},{"key":"author","value":"x"}],
     "url":null,"confidence":0.92}
    """

    @Test func replyBecomesACleanedExtraction() throws {
        let extraction = try CloudPrompt.parse(replyJSON, ocrText: "Email jack@yettobe.co", providerName: "Test")
        #expect(extraction.category == .jobs)
        #expect(extraction.title == "Product Designer at yet to be")
        #expect(extraction.fields == ["company": "yet to be", "remote": "yes"])
        #expect(extraction.confidence == 0.92)
    }

    @Test func unknownCategoryBecomesOther() throws {
        let json = #"{"category":"memes","title":"A meme","summary":"","fields":[],"url":null,"confidence":0.7}"#
        #expect(try CloudPrompt.parse(json, ocrText: "", providerName: "Test").category == .other)
    }

    @Test func missingURLFallsBackToOneInTheText() throws {
        let json = #"{"category":"posts","title":"Launch","summary":"","fields":[],"url":null,"confidence":0.7}"#
        let extraction = try CloudPrompt.parse(json, ocrText: "Try it at https://spacesheep.dev today", providerName: "Test")
        #expect(extraction.url == "https://spacesheep.dev")
    }

    @Test func garbageIsABadReply() {
        #expect(throws: CloudError.badReply("Test")) {
            try CloudPrompt.parse("not json", ocrText: "", providerName: "Test")
        }
    }

    @Test func openAIOutputTextIsExtracted() throws {
        let response = """
        {"output":[{"type":"reasoning","summary":[]},
                   {"type":"message","content":[{"type":"output_text","text":"{\\"a\\":"},{"type":"output_text","text":"1}"}]}]}
        """
        #expect(try OpenAIProvider.outputText(fromResponse: Data(response.utf8), providerName: "OpenAI") == #"{"a":1}"#)
    }

    @Test func streamedReplyIsCollectedUntilCompleted() throws {
        var stream = SSEAccumulator(providerName: "ChatGPT")
        let lines = [
            "event: response.created",
            #"data: {"type":"response.created"}"#,
            #"data: {"type":"response.output_text.delta","delta":"{\"title\":"}"#,
            #"data: {"type":"response.output_text.delta","delta":"\"Hi\"}"}"#,
            #"data: {"type":"response.completed"}"#,
        ]
        var finished = false
        for line in lines where !finished { finished = try stream.consume(line) }
        #expect(finished)
        #expect(try stream.finish() == #"{"title":"Hi"}"#)
    }

    @Test func streamThatNeverCompletesFails() throws {
        var stream = SSEAccumulator(providerName: "ChatGPT")
        _ = try stream.consume(#"data: {"type":"response.output_text.delta","delta":"partial"}"#)
        #expect(throws: CloudError.badReply("ChatGPT")) { try stream.finish() }
    }

    @Test func failedStreamThrows() {
        var stream = SSEAccumulator(providerName: "ChatGPT")
        #expect(throws: CloudError.badReply("ChatGPT")) {
            _ = try stream.consume(#"data: {"type":"response.failed"}"#)
        }
    }

    @Test func geminiTextIsExtracted() throws {
        let response = #"{"candidates":[{"content":{"role":"model","parts":[{"text":"{\"ok\":"},{"text":"true}"}]}}]}"#
        #expect(try GeminiProvider.text(fromResponse: Data(response.utf8)) == #"{"ok":true}"#)
    }

    @Test func blockedGeminiReplyIsEmpty() {
        let response = #"{"promptFeedback":{"blockReason":"SAFETY"}}"#
        #expect(throws: CloudError.emptyReply("Gemini")) {
            try GeminiProvider.text(fromResponse: Data(response.utf8))
        }
    }

    @Test func httpErrorsMapToFriendlyMessages() {
        #expect(CloudError.from(status: 401, body: Data(), provider: "Claude") == .unauthorized("Claude"))
        #expect(CloudError.from(status: 429, body: Data(), provider: "Gemini") == .rateLimited("Gemini"))
        #expect(CloudError.from(status: 429, body: Data(#"{"code":"subscription_sharing_usage_limit_exceeded"}"#.utf8), provider: "ChatGPT") == .planLimitReached)
        #expect(CloudError.from(status: 500, body: Data(), provider: "OpenAI") == .http("OpenAI", 500))
    }

    @Test func pastedKeysAreRecognised() {
        #expect(CloudProviderKind.detect(key: " sk-ant-api03-abc ") == .claude)
        #expect(CloudProviderKind.detect(key: "sk-proj-abc") == .openAI)
        #expect(CloudProviderKind.detect(key: "AIzaSyAbc") == .gemini)
        #expect(CloudProviderKind.detect(key: "hello") == nil)
    }

    @Test func keysAreMaskedForDisplay() {
        #expect(CloudProviderKind.masked("sk-ant-api03-1234567890abcd") == "sk-ant-…abcd")
        #expect(CloudProviderKind.masked("short") == "••••")
    }
}

struct ModelPickerTests {
    @Test func openAIPrefersTheNewestUndatedMini() {
        let ids = ["gpt-5", "gpt-5-mini", "gpt-5-mini-2025-08-07", "gpt-6.1-mini", "gpt-6.1", "gpt-realtime-mini", "whisper-1", "gpt-image-2"]
        #expect(ModelPicker.openAI(ids) == "gpt-6.1-mini")
    }

    @Test func openAIFallsBackToAnyGPTModel() {
        #expect(ModelPicker.openAI(["gpt-6.1", "text-embedding-3"]) == "gpt-6.1")
        #expect(ModelPicker.openAI(["whisper-1"]) == nil)
    }

    @Test func geminiPrefersTheNewestStableFlash() {
        let names = ["models/gemini-3.8-flash", "models/gemini-4-argon", "models/gemini-3.8-flash-preview-09", "models/gemini-3.8-flash-image", "models/gemini-3.5-flash", "models/text-embedding-004"]
        #expect(ModelPicker.gemini(names) == "gemini-3.8-flash")
    }

    @Test func geminiFallsBackWhenThereIsNoFlash() {
        #expect(ModelPicker.gemini(["models/gemini-4-argon"]) == "gemini-4-argon")
        #expect(ModelPicker.gemini([]) == nil)
    }
}
