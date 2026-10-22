import Testing

@testable import OkenaCore

private let envelope = TainaError.api(APIError(
    code: "validation_failed",
    status: 422,
    message: "Confira os campos e tente de novo.",
    details: ["username": ["não pode ficar em branco"], "password": ["curta demais"]]
))

@Test func fieldMessagesComeFromTheFirstFieldWithAny() {
    #expect(envelope.messages(for: ["username"]) == ["não pode ficar em branco"])
    #expect(envelope.messages(for: ["display_name", "password"]) == ["curta demais"])
    #expect(envelope.messages(for: ["missing"]) == [])
}

@Test func aLocalErrorCarriesNoFieldMessages() {
    #expect(TainaError.notSignedIn.messages(for: ["username"]) == [])
    #expect(TainaError.network("offline").messages(for: ["password"]) == [])
}
