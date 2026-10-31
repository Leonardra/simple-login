import Testing

func waitUntil(
    _ condition: () -> Bool,
    timeout: Duration = .seconds(2),
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while !condition() && clock.now < deadline {
        try? await Task.sleep(for: .milliseconds(1))
    }

    #expect(condition(), "the awaited condition never became true", sourceLocation: sourceLocation)
}
