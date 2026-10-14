import Foundation
import Testing

@testable import OkenaCore

@Test func bareHostGetsHTTPS() {
    let parsed = InstanceAddress.parse(input: "taina.minhacasa.ts.net")
    #expect(parsed.value?.url.absoluteString == "https://taina.minhacasa.ts.net")
}

@Test func trailingSlashIsDropped() {
    let parsed = InstanceAddress.parse(input: "https://taina.local/")
    #expect(parsed.value?.url.absoluteString == "https://taina.local")
}

@Test func bareHostWithTrailingSlashGetsHTTPS() {
    let parsed = InstanceAddress.parse(input: "taina.local/")
    #expect(parsed.value?.url.absoluteString == "https://taina.local")
}

@Test func whitespaceIsTrimmed() {
    let parsed = InstanceAddress.parse(input: "  taina.local \n")
    #expect(parsed.value?.url.absoluteString == "https://taina.local")
}

@Test func portIsKept() {
    let parsed = InstanceAddress.parse(input: "http://10.0.0.5:4000")
    #expect(parsed.value?.url.absoluteString == "http://10.0.0.5:4000")
}

@Test func lanNameOverHTTPIsAccepted() {
    let parsed = InstanceAddress.parse(input: "http://taina")
    #expect(parsed.value?.url.absoluteString == "http://taina")
}

@Test func dotLocalNameOverHTTPIsAccepted() {
    let parsed = InstanceAddress.parse(input: "http://taina.local")
    #expect(parsed.value?.url.absoluteString == "http://taina.local")
}

@Test func privateIPv4OverHTTPIsAccepted() {
    for host in ["192.168.1.10", "10.0.0.5", "127.0.0.1", "169.254.10.2", "172.16.0.1", "172.31.255.255"] {
        let parsed = InstanceAddress.parse(input: "http://\(host)")
        #expect(parsed.value?.url.host() == host, "host \(host) should be local")
    }
}

@Test func boundaryOfPrivateRangeIsInsecure() {
    #expect(InstanceAddress.parse(input: "http://172.32.0.1").error == .invalidAddress(.insecure))
    #expect(InstanceAddress.parse(input: "http://11.0.0.5").error == .invalidAddress(.insecure))
}

@Test func publicNameOverHTTPIsInsecure() {
    #expect(InstanceAddress.parse(input: "http://exemplo.com").error == .invalidAddress(.insecure))
}

@Test func httpsIsAlwaysAccepted() {
    let parsed = InstanceAddress.parse(input: "https://exemplo.com")
    #expect(parsed.value?.url.absoluteString == "https://exemplo.com")
}

@Test func otherSchemeIsUnsupported() {
    #expect(InstanceAddress.parse(input: "ftp://taina.local").error == .invalidAddress(.unsupportedScheme))
}

@Test func emptyInputIsEmpty() {
    #expect(InstanceAddress.parse(input: "").error == .invalidAddress(.empty))
    #expect(InstanceAddress.parse(input: "   \n\t").error == .invalidAddress(.empty))
}

@Test func missingHostIsMalformed() {
    #expect(InstanceAddress.parse(input: "https://").error == .invalidAddress(.malformed))
}

@Test func embeddedCredentialsAreMalformed() {
    #expect(InstanceAddress.parse(input: "https://user:pass@exemplo.com").error == .invalidAddress(.malformed))
}

@Test func pathQueryAndFragmentAreDropped() {
    let parsed = InstanceAddress.parse(input: "https://exemplo.com/painel?x=1#topo")
    #expect(parsed.value?.url.absoluteString == "https://exemplo.com")
}

@Test func localIPv6OverHTTPIsAccepted() {
    #expect(InstanceAddress.parse(input: "http://[::1]:4000").value != nil)
    #expect(InstanceAddress.parse(input: "http://[fe80::1]").value != nil)
    #expect(InstanceAddress.parse(input: "http://[fd7a:4c2d::1]").value != nil)
}

@Test func displayIsTheBareHost() throws {
    let address = try #require(InstanceAddress.parse(input: "https://taina.minhacasa.ts.net:8443").value)
    #expect(address.display == "taina.minhacasa.ts.net")
}
